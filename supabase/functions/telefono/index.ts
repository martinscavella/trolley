// La verifica del numero di telefono passa da qui (5.1; ADR-011): il codice
// SMS lo manda e lo controlla Twilio Verify, con le chiavi che stanno solo sul
// server (i segreti TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_VERIFY_SID).
//
// Prima di ogni invio e di ogni controllo si chiede al database se si può
// (telefono_invio, telefono_controllo: la parte pubblica, i 18 anni, un numero
// per account, il tetto); quando il codice è giusto il numero si scrive
// (telefono_conferma). Sono funzioni che solo il server può chiamare: con la
// chiave di servizio, dopo aver chiesto all'accesso chi è la persona.
//
//   POST /telefono/invia     { numero }          → { esito: 'inviato' | 'gia' }
//   POST /telefono/verifica  { numero, codice }  → { esito: 'verificato' }
//
// Gli errori sono { codice }: accesso, numero, chiusa, eta, usato, tetto,
// sbagliato, scaduto, fornitore, server. Il numero va nel corpo, non
// nell'indirizzo: non finisce nei registri delle richieste.
//
// TELEFONO_PROVA, se c'è, elenca numeri finti con il loro codice
// («+393400000001=123456,…»): per provare l'app senza mandare SMS. Si toglie
// prima di aprire la parte pubblica (punti aperti).
//
// Si pubblica senza il controllo dell'accesso del gateway (verify_jwt
// spento), come `mappe`: chi è la persona lo dice l'accesso, qui sotto.

const server = Deno.env.get('SUPABASE_URL') ?? '';
const chiavePubblica = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const chiaveServizio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const twilioConto = Deno.env.get('TWILIO_ACCOUNT_SID') ?? '';
const twilioChiave = Deno.env.get('TWILIO_AUTH_TOKEN') ?? '';
const twilioServizio = Deno.env.get('TWILIO_VERIFY_SID') ?? '';

/// I numeri di prova e il loro codice.
const prova = new Map(
  (Deno.env.get('TELEFONO_PROVA') ?? '')
    .split(',')
    .map((coppia) => coppia.trim().split('='))
    .filter(([n, c]) => n && c)
    .map(([n, c]) => [n.trim(), c.trim()] as [string, string]),
);

const formato = /^\+[1-9][0-9]{7,14}$/;
const formatoCodice = /^[0-9]{4,10}$/;

function risposta(stato: number, corpo: Record<string, string>): Response {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: { 'content-type': 'application/json' },
  });
}

const errore = (stato: number, codice: string) => risposta(stato, { codice });

/// Chi chiama, dal suo accesso. `null` se non è dentro.
async function chi(richiesta: Request): Promise<string | null> {
  const accesso = richiesta.headers.get('authorization');
  if (!accesso) return null;
  try {
    const r = await fetch(`${server}/auth/v1/user`, {
      headers: {
        authorization: accesso,
        apikey: richiesta.headers.get('apikey') ?? chiavePubblica,
      },
    });
    if (!r.ok) {
      await r.body?.cancel();
      return null;
    }
    const utente = await r.json();
    return typeof utente?.id === 'string' ? utente.id : null;
  } catch {
    return null;
  }
}

/// Una delle tre funzioni del database, con la chiave di servizio. Restituisce
/// il testo che dicono, o `null` se il database non risponde.
async function chiedi(
  funzione: 'telefono_invio' | 'telefono_controllo' | 'telefono_conferma',
  utente: string,
  numero: string,
): Promise<string | null> {
  try {
    const r = await fetch(`${server}/rest/v1/rpc/${funzione}`, {
      method: 'POST',
      headers: {
        apikey: chiaveServizio,
        authorization: `Bearer ${chiaveServizio}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ p_utente: utente, p_numero: numero }),
    });
    if (!r.ok) {
      await r.body?.cancel();
      return null;
    }
    const esito = await r.json();
    return typeof esito === 'string' ? esito : null;
  } catch {
    return null;
  }
}

/// Twilio Verify, con le credenziali del conto.
async function twilio(percorso: string, campi: Record<string, string>) {
  return await fetch(
    `https://verify.twilio.com/v2/Services/${twilioServizio}/${percorso}`,
    {
      method: 'POST',
      headers: {
        authorization: `Basic ${btoa(`${twilioConto}:${twilioChiave}`)}`,
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams(campi),
    },
  );
}

/// I no del database, detti all'app.
const noDelDatabase: Record<string, [number, string]> = {
  profilo: [403, 'accesso'],
  chiusa: [403, 'chiusa'],
  eta: [403, 'eta'],
  numero: [400, 'numero'],
  usato: [409, 'usato'],
  tetto: [429, 'tetto'],
};

async function invia(utente: string, numero: string): Promise<Response> {
  const si = await chiedi('telefono_invio', utente, numero);
  if (si === null) return errore(502, 'server');
  if (si === 'gia') return risposta(200, { esito: 'gia' });
  if (si !== 'ok') {
    const [stato, codice] = noDelDatabase[si] ?? [502, 'server'];
    return errore(stato, codice);
  }
  if (prova.has(numero)) return risposta(200, { esito: 'inviato' });
  try {
    const r = await twilio('Verifications', {
      To: numero,
      Channel: 'sms',
      Locale: 'it',
    });
    if (r.status === 429) {
      await r.body?.cancel();
      return errore(429, 'tetto');
    }
    if (r.status === 400) {
      // Un numero che Twilio non sa raggiungere (60200, 60205…).
      await r.body?.cancel();
      return errore(400, 'numero');
    }
    if (!r.ok) {
      await r.body?.cancel();
      return errore(502, 'fornitore');
    }
    await r.body?.cancel();
    return risposta(200, { esito: 'inviato' });
  } catch {
    return errore(502, 'fornitore');
  }
}

async function verifica(
  utente: string,
  numero: string,
  codice: string,
): Promise<Response> {
  const si = await chiedi('telefono_controllo', utente, numero);
  if (si === null) return errore(502, 'server');
  if (si !== 'ok') return errore(429, 'tetto');

  let giusto: boolean;
  if (prova.has(numero)) {
    giusto = prova.get(numero) === codice;
  } else {
    try {
      const r = await twilio('VerificationCheck', { To: numero, Code: codice });
      // 404: il codice non c'è più (scaduto, già usato, troppi tentativi).
      if (r.status === 404) {
        await r.body?.cancel();
        return errore(410, 'scaduto');
      }
      if (r.status === 429) {
        await r.body?.cancel();
        return errore(429, 'tetto');
      }
      if (!r.ok) {
        await r.body?.cancel();
        return errore(502, 'fornitore');
      }
      const corpo = await r.json();
      giusto = corpo?.status === 'approved';
    } catch {
      return errore(502, 'fornitore');
    }
  }
  if (!giusto) return errore(422, 'sbagliato');

  const scritto = await chiedi('telefono_conferma', utente, numero);
  if (scritto === 'ok') return risposta(200, { esito: 'verificato' });
  if (scritto === 'usato') return errore(409, 'usato');
  if (scritto === 'profilo') return errore(403, 'accesso');
  return errore(502, 'server');
}

Deno.serve(async (richiesta) => {
  if (!chiaveServizio) return errore(502, 'server');
  const parti = new URL(richiesta.url).pathname.split('/').filter(Boolean);
  const [cosa, ...resto] = parti.slice(parti.indexOf('telefono') + 1);
  if (richiesta.method !== 'POST' || resto.length > 0 ||
      (cosa !== 'invia' && cosa !== 'verifica')) {
    return errore(404, 'indirizzo');
  }
  const utente = await chi(richiesta);
  if (!utente) return errore(401, 'accesso');

  let corpo: { numero?: unknown; codice?: unknown };
  try {
    corpo = await richiesta.json();
  } catch {
    return errore(400, 'numero');
  }
  const numero = typeof corpo.numero === 'string' ? corpo.numero : '';
  if (!formato.test(numero)) return errore(400, 'numero');
  // Senza Twilio funzionano solo i numeri di prova.
  if (!prova.has(numero) && (!twilioConto || !twilioChiave || !twilioServizio)) {
    return errore(502, 'fornitore');
  }

  if (cosa === 'invia') return invia(utente, numero);
  const codice = typeof corpo.codice === 'string' ? corpo.codice.trim() : '';
  if (!formatoCodice.test(codice)) return errore(422, 'sbagliato');
  return verifica(utente, numero, codice);
});

// Le mappe passano da qui (U.2; ADR-006): riquadri, ricerche e percorsi di
// Geoapify, con la chiave che sta solo sul server (il segreto
// GEOAPIFY_CHIAVE) e il tetto per persona, per viaggio e per giorno.
//
// Prima di ogni chiamata si chiede a consuma_mappe, con l'accesso di chi
// chiama: è il server che sa chi è, se partecipa al viaggio e se è sotto il
// tetto (migrazione tetto_mappe). Al tetto si risponde 429 e il fornitore non
// si chiama.
//
// Cosa passa di qui: le zone di mappa, il testo cercato e i capi di un
// percorso vanno al fornitore e tornano indietro, senza restare. Ricerche e
// percorsi arrivano nel corpo, non nell'indirizzo: così non finiscono nei
// registri delle richieste. Il fornitore vede il server, non il telefono.
//
//   GET  /mappe/riquadro/{z}/{x}/{y}.png  (o {y}@2x.png), intestazione x-viaggio
//   POST /mappe/cerca     { viaggio, parametri }  → /v1/geocode/autocomplete
//   POST /mappe/percorso  { viaggio, parametri }  → /v1/routing
//
// Si pubblica senza il controllo dell'accesso del gateway (verify_jwt
// spento): lo fa consuma_mappe, attraverso le regole del database.

const chiave = Deno.env.get('GEOAPIFY_CHIAVE') ?? '';
const server = Deno.env.get('SUPABASE_URL') ?? '';
const chiavePubblica = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const stile = 'positron';

/// I parametri che si passano al fornitore, e nient'altro.
const ammessi = {
  cerca: {
    percorso: '/v1/geocode/autocomplete',
    parametri: ['text', 'lang', 'limit', 'format', 'bias', 'filter'],
  },
  percorso: {
    percorso: '/v1/routing',
    parametri: ['waypoints', 'mode', 'lang', 'details'],
  },
} as const;

type Tipo = 'riquadri' | 'ricerche' | 'percorsi';

function errore(stato: number, codice: string): Response {
  return new Response(JSON.stringify({ codice }), {
    status: stato,
    headers: { 'content-type': 'application/json' },
  });
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/// Chiede al database se chi chiama può fare una chiamata di [tipo] nel
/// viaggio. `null`: sì, e l'ha contata; altrimenti la risposta da dare.
async function consuma(
  richiesta: Request,
  viaggio: unknown,
  tipo: Tipo,
): Promise<Response | null> {
  const accesso = richiesta.headers.get('authorization');
  if (!accesso) return errore(401, 'accesso');
  if (typeof viaggio !== 'string' || !uuid.test(viaggio)) {
    return errore(400, 'viaggio');
  }
  let risposta: Response;
  try {
    risposta = await fetch(`${server}/rest/v1/rpc/consuma_mappe`, {
      method: 'POST',
      headers: {
        authorization: accesso,
        apikey: richiesta.headers.get('apikey') ?? chiavePubblica,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ p_viaggio: viaggio, p_tipo: tipo }),
    });
  } catch {
    return errore(502, 'server');
  }
  if (risposta.status === 401 || risposta.status === 403) {
    await risposta.body?.cancel();
    return errore(401, 'accesso');
  }
  if (!risposta.ok) {
    const corpo = await risposta.json().catch(() => ({}));
    if (corpo?.code === 'TR404') return errore(403, 'viaggio');
    if (corpo?.code === 'TR401' || corpo?.code === '42501') {
      return errore(401, 'accesso');
    }
    return errore(502, 'server');
  }
  return (await risposta.json()) === true ? null : errore(429, 'tetto');
}

/// Il fornitore non risponde, o non ha più crediti per oggi: per l'app è lo
/// stesso, la mappa non risponde.
function dalFornitore(risposta: Response, intestazioni: string[]): Response {
  const nonCambiato = risposta.status === 304;
  if (!risposta.ok && !nonCambiato) {
    risposta.body?.cancel();
    return errore(502, 'fornitore');
  }
  const headers = new Headers();
  for (const nome of intestazioni) {
    const valore = risposta.headers.get(nome);
    if (valore) headers.set(nome, valore);
  }
  // Il riquadro che l'app ha già non è cambiato: torna senza corpo.
  if (nonCambiato) return new Response(null, { status: 304, headers });
  return new Response(risposta.body, { status: 200, headers });
}

async function riquadro(richiesta: Request, resto: string[]): Promise<Response> {
  const [z, x, ultimo] = resto;
  const y = /^(\d+)(@2x)?\.png$/.exec(ultimo ?? '');
  if (!/^\d+$/.test(z ?? '') || !/^\d+$/.test(x ?? '') || !y) {
    return errore(404, 'riquadro');
  }
  if (Number(z) > 20) return errore(404, 'riquadro');
  const no = await consuma(richiesta, richiesta.headers.get('x-viaggio'), 'riquadri');
  if (no) return no;
  // Geoapify chiede di ricontrollare ogni riquadro (no-cache): l'app manda
  // quello che ha, e se non è cambiato torna un 304 senza corpo.
  const condizioni = new Headers();
  for (const nome of ['if-none-match', 'if-modified-since']) {
    const valore = richiesta.headers.get(nome);
    if (valore) condizioni.set(nome, valore);
  }
  try {
    const risposta = await fetch(
      `https://maps.geoapify.com/v1/tile/${stile}/${z}/${x}/${y[1]}${y[2] ?? ''}.png` +
        `?apiKey=${encodeURIComponent(chiave)}`,
      { headers: condizioni },
    );
    return dalFornitore(risposta, [
      'content-type',
      'cache-control',
      'etag',
      'last-modified',
      'expires',
    ]);
  } catch {
    return errore(502, 'fornitore');
  }
}

async function chiedi(
  richiesta: Request,
  cosa: keyof typeof ammessi,
  tipo: Tipo,
): Promise<Response> {
  let corpo: { viaggio?: unknown; parametri?: Record<string, unknown> };
  try {
    corpo = await richiesta.json();
  } catch {
    return errore(400, 'corpo');
  }
  const { percorso, parametri } = ammessi[cosa];
  const indirizzo = new URL(`https://api.geoapify.com${percorso}`);
  for (const nome of parametri) {
    const valore = corpo.parametri?.[nome];
    if (typeof valore === 'string' && valore.length <= 300) {
      indirizzo.searchParams.set(nome, valore);
    }
  }
  const no = await consuma(richiesta, corpo.viaggio, tipo);
  if (no) return no;
  indirizzo.searchParams.set('apiKey', chiave);
  try {
    return dalFornitore(await fetch(indirizzo), ['content-type']);
  } catch {
    return errore(502, 'fornitore');
  }
}

Deno.serve((richiesta) => {
  if (!chiave) return errore(502, 'fornitore');
  // L'indirizzo arriva come /mappe/…: si guarda quello che segue.
  const parti = new URL(richiesta.url).pathname.split('/').filter(Boolean);
  const [cosa, ...resto] = parti.slice(parti.indexOf('mappe') + 1);
  if (richiesta.method === 'GET' && cosa === 'riquadro') {
    return riquadro(richiesta, resto);
  }
  if (richiesta.method === 'POST' && cosa === 'cerca' && resto.length === 0) {
    return chiedi(richiesta, 'cerca', 'ricerche');
  }
  if (richiesta.method === 'POST' && cosa === 'percorso' && resto.length === 0) {
    return chiedi(richiesta, 'percorso', 'percorsi');
  }
  return errore(404, 'indirizzo');
});

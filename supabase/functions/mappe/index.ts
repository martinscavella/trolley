// Le mappe passano da qui (U.2; ADR-006, ADR-014): la ricerca dei posti
// con Google Places (New), e il conto delle guide. La mappa e la guida sono
// sul telefono, con gli SDK di Google (CR-06, passi 2 e 4): qui non passano.
// La chiave di Places sta solo sul server (il segreto GOOGLE_MAPS_CHIAVE),
// con il tetto per persona, per viaggio e per giorno.
//
// Prima di ogni chiamata si chiede a consuma_mappe, con l'accesso di chi
// chiama: è il server che sa chi è, se partecipa al viaggio e se è sotto il
// tetto (migrazione tetto_mappe). Al tetto si risponde 429 e il fornitore non
// si chiama.
//
// Cosa passa di qui: il testo cercato e il posto scelto vanno a Google e
// tornano indietro, senza restare. Arrivano nel corpo, non nell'indirizzo:
// così non finiscono nei registri delle richieste. Google vede il server,
// non il telefono.
//
//   POST /mappe/cerca     { viaggio, parametri }  → Google, places:autocomplete
//   POST /mappe/posto     { viaggio, parametri }  → Google, places/{id}
//   POST /mappe/scheda    { viaggio, parametri }  → Google, places/{id}, con orari
//   POST /mappe/guida     { viaggio }             → nessuno: conta la guida
//
// La guida (il Navigation SDK, sul telefono) si paga a destinazione: prima
// di partire l'app chiede qui, e la destinazione si conta sul tetto come
// `percorsi` (il nome del contatore dai tempi di Geoapify). Non arriva né il
// posto né dove si è: solo il viaggio.
//
// La ricerca e il posto scelto vanno nella stessa sessione di Google
// (`sessione`): così i suggerimenti non si pagano, si paga il posto scelto.
// Del posto scelto si chiedono solo le coordinate e l'indirizzo (Place
// Details Essentials). La scheda del posto, nel dettaglio di una tappa,
// chiede anche gli orari e la descrizione (Enterprise e Atmosphere: le più
// care, 1000 al mese gratis). Si contano tutti come `ricerche` sul tetto.
//
// Si pubblica senza il controllo dell'accesso del gateway (verify_jwt
// spento): lo fa consuma_mappe, attraverso le regole del database.

const chiaveGoogle = Deno.env.get('GOOGLE_MAPS_CHIAVE') ?? '';
const server = Deno.env.get('SUPABASE_URL') ?? '';
const chiavePubblica = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

type Tipo = 'ricerche' | 'percorsi';

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
  if (!risposta.ok) {
    risposta.body?.cancel();
    return errore(502, 'fornitore');
  }
  const headers = new Headers();
  for (const nome of intestazioni) {
    const valore = risposta.headers.get(nome);
    if (valore) headers.set(nome, valore);
  }
  return new Response(risposta.body, { status: 200, headers });
}

// ─── Google Places (New) ────────────────────────────────────────────────

const places = 'https://places.googleapis.com/v1';

/// Un testo corto, o niente.
function testo(valore: unknown, massimo = 300): string | undefined {
  return typeof valore === 'string' && valore.length > 0 && valore.length <= massimo
    ? valore
    : undefined;
}

/// Un numero finito fra [min] e [max], o niente.
function numero(valore: unknown, min: number, max: number): number | undefined {
  return typeof valore === 'number' && Number.isFinite(valore) && valore >= min && valore <= max
    ? valore
    : undefined;
}

async function leggiCorpo(
  richiesta: Request,
): Promise<{ viaggio?: unknown; parametri?: Record<string, unknown> } | null> {
  try {
    const corpo = await richiesta.json();
    return corpo && typeof corpo === 'object' ? corpo : null;
  } catch {
    return null;
  }
}

/// I suggerimenti per un testo: `{ testo, lingua?, sessione?, lat?, lon?,
/// raggio? }`. Vicino a lat/lon prima, ma non solo lì: una gita in
/// giornata ci sta.
async function cerca(richiesta: Request): Promise<Response> {
  const corpo = await leggiCorpo(richiesta);
  if (!corpo) return errore(400, 'corpo');
  const p = corpo.parametri ?? {};
  const input = testo(p.testo, 200);
  if (!input) return errore(400, 'parametri');
  const lat = numero(p.lat, -90, 90);
  const lon = numero(p.lon, -180, 180);
  const raggio = numero(p.raggio, 1, 50000) ?? 40000;
  const chiesta: Record<string, unknown> = {
    input,
    languageCode: testo(p.lingua, 10) ?? 'it',
  };
  const sessione = testo(p.sessione, 100);
  if (sessione) chiesta.sessionToken = sessione;
  if (lat !== undefined && lon !== undefined) {
    chiesta.locationBias = {
      circle: { center: { latitude: lat, longitude: lon }, radius: raggio },
    };
  }
  const no = await consuma(richiesta, corpo.viaggio, 'ricerche');
  if (no) return no;
  try {
    const risposta = await fetch(`${places}/places:autocomplete`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-goog-api-key': chiaveGoogle,
        // Solo quello che l'app legge.
        'x-goog-fieldmask':
          'suggestions.placePrediction.placeId,' +
          'suggestions.placePrediction.structuredFormat,' +
          'suggestions.placePrediction.types',
      },
      body: JSON.stringify(chiesta),
    });
    return dalFornitore(risposta, ['content-type']);
  } catch {
    return errore(502, 'fornitore');
  }
}

/// I campi che si chiedono: per il posto scelto, e per la sua scheda.
const campi = {
  posto: 'id,location,formattedAddress',
  scheda:
    'id,location,formattedAddress,businessStatus,utcOffsetMinutes,' +
    'currentOpeningHours.openNow,currentOpeningHours.nextOpenTime,' +
    'currentOpeningHours.nextCloseTime,regularOpeningHours.periods,' +
    'editorialSummary',
} as const;

/// Il posto: `{ id, lingua?, sessione? }` → coordinate e indirizzo; per la
/// scheda anche gli orari e la descrizione.
async function posto(
  richiesta: Request,
  cosa: keyof typeof campi,
): Promise<Response> {
  const corpo = await leggiCorpo(richiesta);
  if (!corpo) return errore(400, 'corpo');
  const p = corpo.parametri ?? {};
  const id = testo(p.id, 300);
  if (!id || !/^[A-Za-z0-9_-]+$/.test(id)) return errore(400, 'parametri');
  const no = await consuma(richiesta, corpo.viaggio, 'ricerche');
  if (no) return no;
  const indirizzo = new URL(`${places}/places/${id}`);
  indirizzo.searchParams.set('languageCode', testo(p.lingua, 10) ?? 'it');
  const sessione = testo(p.sessione, 100);
  if (sessione) indirizzo.searchParams.set('sessionToken', sessione);
  try {
    const risposta = await fetch(indirizzo, {
      headers: {
        'x-goog-api-key': chiaveGoogle,
        // Mai il nome, le foto, le recensioni.
        'x-goog-fieldmask': campi[cosa],
      },
    });
    return dalFornitore(risposta, ['content-type']);
  } catch {
    return errore(502, 'fornitore');
  }
}

/// La guida: `{ viaggio }`. Conta una destinazione sul tetto, e basta.
async function guida(richiesta: Request): Promise<Response> {
  const corpo = await leggiCorpo(richiesta);
  if (!corpo) return errore(400, 'corpo');
  const no = await consuma(richiesta, corpo.viaggio, 'percorsi');
  if (no) return no;
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}

Deno.serve((richiesta) => {
  // L'indirizzo arriva come /mappe/…: si guarda quello che segue.
  const parti = new URL(richiesta.url).pathname.split('/').filter(Boolean);
  const [cosa, ...resto] = parti.slice(parti.indexOf('mappe') + 1);
  const post = richiesta.method === 'POST' && resto.length === 0;
  if (post && cosa === 'guida') return guida(richiesta);
  if (post && (cosa === 'cerca' || cosa === 'posto' || cosa === 'scheda')) {
    if (!chiaveGoogle) return errore(502, 'fornitore');
    return cosa === 'cerca' ? cerca(richiesta) : posto(richiesta, cosa);
  }
  return errore(404, 'indirizzo');
});

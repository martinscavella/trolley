// Le mappe passano da qui (U.2; ADR-006, ADR-014): i riquadri e i percorsi
// di Geoapify, finché la mappa e la guida non passano a Google (CR-06, passi
// 2 e 4), e la ricerca dei posti con Google Places (New). Le chiavi stanno
// solo sul server (i segreti GEOAPIFY_CHIAVE e GOOGLE_MAPS_CHIAVE), con il
// tetto per persona, per viaggio e per giorno.
//
// Prima di ogni chiamata si chiede a consuma_mappe, con l'accesso di chi
// chiama: è il server che sa chi è, se partecipa al viaggio e se è sotto il
// tetto (migrazione tetto_mappe). Al tetto si risponde 429 e il fornitore non
// si chiama.
//
// Cosa passa di qui: le zone di mappa, il testo cercato, il posto scelto e i
// capi di un percorso vanno al fornitore e tornano indietro, senza restare.
// Ricerche e percorsi arrivano nel corpo, non nell'indirizzo: così non
// finiscono nei registri delle richieste. Il fornitore vede il server, non il
// telefono.
//
//   GET  /mappe/riquadro/{z}/{x}/{y}.png  (o {y}@2x.png), intestazione x-viaggio
//   POST /mappe/cerca     { viaggio, parametri }  → Google, places:autocomplete
//   POST /mappe/posto     { viaggio, parametri }  → Google, places/{id}
//   POST /mappe/scheda    { viaggio, parametri }  → Google, places/{id}, con orari
//   POST /mappe/percorso  { viaggio, parametri }  → Geoapify, /v1/routing
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

const chiave = Deno.env.get('GEOAPIFY_CHIAVE') ?? '';
const chiaveGoogle = Deno.env.get('GOOGLE_MAPS_CHIAVE') ?? '';
const server = Deno.env.get('SUPABASE_URL') ?? '';
const chiavePubblica = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

// Colorato e morbido, come Mappe di iPhone: terra sabbia, acqua azzurra,
// parchi verdi, strade bianche (scelto dall'utente il 1° novembre 2026; era
// `positron`, grigio). L'app mette lo stesso nome nell'indirizzo dei riquadri,
// perché la sua memoria non riusi quelli dello stile di prima.
const stile = 'klokantech-basic';

/// I parametri che si passano al fornitore, e nient'altro.
const ammessi = {
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

Deno.serve((richiesta) => {
  // L'indirizzo arriva come /mappe/…: si guarda quello che segue.
  const parti = new URL(richiesta.url).pathname.split('/').filter(Boolean);
  const [cosa, ...resto] = parti.slice(parti.indexOf('mappe') + 1);
  const post = richiesta.method === 'POST' && resto.length === 0;
  if (post && (cosa === 'cerca' || cosa === 'posto' || cosa === 'scheda')) {
    if (!chiaveGoogle) return errore(502, 'fornitore');
    return cosa === 'cerca' ? cerca(richiesta) : posto(richiesta, cosa);
  }
  if (!chiave) return errore(502, 'fornitore');
  if (richiesta.method === 'GET' && cosa === 'riquadro') {
    return riquadro(richiesta, resto);
  }
  if (post && cosa === 'percorso') {
    return chiedi(richiesta, 'percorso', 'percorsi');
  }
  return errore(404, 'indirizzo');
});

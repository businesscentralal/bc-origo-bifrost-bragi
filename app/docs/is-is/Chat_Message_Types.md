# Spjallskilaboðategundir

Þetta skjal lýsir spjalltengdum skilaboðategundum í Bifröst Bragi-endingnum.

## Yfirlit

Bifröst Bragi bætir einni skilaboðategund við sendistjóra Bifröst Foundation: `LLM.Prompt.Complete`. Hún er einskotsframkvæmd á móti mállíkaninu sem stillt er á færslu í **Bifröst mállíkan** — kerfiskvaðning og notandakvaðning inn, textasvar til baka.

Skilaboðategundin er vísvitandi einföld í samanburði við gagnvirka Bifröst-spjallreitinn:

- **Engin tól.** MCP-verkfæraþjónninn er ekki tengdur, svo líkanið getur hvorki lesið né skrifað Business Central-gögn meðan á kallinu stendur.
- **Engin ræsing.** Hvorki auðkennisblokk né hæfni mállíkansins er skotið inn. Gildið sem sendandinn setur í `system` er öll kerfiskvaðningin.
- **Engin samtalsstaða.** Hvert kall er sjálfstætt og ekkert flyst yfir í næsta kall.

Þetta gerir hana að almennu reikniskrefi fyrir leikbækur og áætluð verk — dagsetningareikninga, flokkun, útdrátt, þýðingu, samantekt, síugerð og frjálsa textagerð — alls staðar þar sem engin staðalskilaboðategund nær yfir skrefið.

Bragi skráir tegundina á `Message Type ori`-tegundasafn Foundation með `enumextension "Bragi Message Type ori"` (10035399), svo henni er dreift nákvæmlega eins og skilaboðategundum Foundation: um `tasks`-API-endapunktinn, um biðröðina eða um MCP-verkfærið `call_message_type`.

## Listi yfir skilaboðategundir

| Skilaboðategund | Stefna | Tilgangur |
|-----------------|--------|-----------|
| [LLM.Prompt.Complete](#llmpromptcomplete) | Útlæg | Einskots framkvæmd mállíkans — senda kvaðningu, fá texta til baka |

---

## LLM.Prompt.Complete

**Stefna**: Útlæg (Svar við beiðni)

**Tilgangur**: Sendir kerfiskvaðningu og notandakvaðningu til mállíkanaveitandans sem stilltur er á það Bifröst mállíkan sem leyst er upp, og skilar textasvari líkansins. Getur einnig sent skrá — annaðhvort beint í beiðninni eða sótta úr viðhengisfærslu í Business Central — til þeirra veitenda sem taka við skjölum og myndum.

### Beiðnisnið

Bifröst-færibreytur:
```json
{
  "specversion": "1.0",
  "type": "LLM.Prompt.Complete",
  "source": "MyApp v1.0",
  "datacontenttype": "application/json",
  "data": "{}"
}
```

#### Gagnafæribreytur beiðni

| Færibreyta | Tegund | Nauðsynleg | Lýsing |
|------------|--------|------------|--------|
| `prompt` | String | Já | Notandakvaðningin — verkefnið eða spurningin fyrir líkanið. |
| `system` | String | Nei | Kerfiskvaðning sem stýrir hegðun líkansins. Send óbreytt; engri ræsingu, auðkennisblokk né hæfni er bætt við. |
| `roleCode` | String (Code[20]) | Nei | Kóði Bifröst mállíkansins sem nota skal. Sleppt til að nota stillt eða sjálfgefið mállíkan sendandans. |
| `file` | Object | Nei | Skrá sem fylgir beint með beiðninni og er send óbreytt til veitandans sem eina færslan í `files`-fylki álagsins. Notaðu `data` (base64), `mimeType` og `fileName`. |
| `attachment` | Object | Nei | Tilvísun í viðhengisfærslu í Business Central sem Bragi les og breytir í skráarfærslu. Hunsuð þegar `file` fylgir með. |

`attachment`-hluturinn:

| Reitur | Tegund | Nauðsynlegur | Lýsing |
|--------|--------|--------------|--------|
| `table` | String | Já | `"Incoming Document Attachment"` eða `"Document Attachment"`. Öðrum gildum er sleppt og engin skrá er send. |
| `systemId` | GUID | Já | System Id viðhengisfærslunnar. Færsla sem finnst ekki eða er innihaldslaus er hunsuð og engin skrá er send. |

Skráarfærslan sem verður til ber `data` (base64-innihald), `fileName` (heiti færslunnar, með skráarendingu bætt aftan við ef hana vantar) og `mimeType`, leitt af skráarendingunni:

| Skráarending | `mimeType` |
|--------------|------------|
| `pdf` | `application/pdf` |
| `png` | `image/png` |
| `jpg`, `jpeg` | `image/jpeg` |
| `gif` | `image/gif` |
| `webp` | `image/webp` |
| `xml` | `application/xml` |
| `json` | `application/json` |
| `txt`, `csv` | `text/plain` |
| allt annað | `application/octet-stream` |

#### Dæmi — Útdráttur gagna

```json
{
  "prompt": "Extract the invoice number, date, and total from the following text:\n\nInvoice #4521\nDate: 2025-03-15\nTotal: 1250.00",
  "system": "Extract structured data from text. Return valid JSON with keys: invoiceNo, date, total.",
  "roleCode": "CLAUDE"
}
```

#### Dæmi — Dagsetningareikningur

```json
{
  "system": "Return ONLY a JSON object with startDate and endDate in YYYY-MM-DD format. No explanation.",
  "prompt": "Today is 2026-08-30. What are the first and last day of last month?"
}
```

Textasvar: `{"startDate":"2026-07-01","endDate":"2026-07-31"}`

#### Dæmi — Flokkun

```json
{
  "system": "Classify the document. Return ONLY one of: Invoice, CreditMemo, DeliveryNote, PurchaseOrder, Unknown.",
  "prompt": "Vendor 30000, document dated 2026-08-14, lines reference return of 4 units."
}
```

#### Dæmi — Síugerð

```json
{
  "system": "Return ONLY a BC tableView filter string. No explanation.",
  "prompt": "Today is 2026-08-30. Filter Sales Invoice Header where Posting Date is in the previous fiscal quarter (April-June 2026) and Sell-to Customer No. starts with 1."
}
```

Textasvar: `WHERE(Posting Date=FILTER(2026-04-01..2026-06-30),Sell-to Customer No.=FILTER(1*))`

#### Dæmi — Textagerð á íslensku

```json
{
  "roleCode": "KAPPI",
  "system": "Write a polite payment reminder in Icelandic. Include amount and due date. Max 500 characters. Return ONLY the text.",
  "prompt": "Customer Alfreð Bjarnason, overdue amount 245.000 ISK, oldest due date 2026-07-15."
}
```

#### Dæmi — Viðhengi af móttökuskjali

```json
{
  "system": "Extract invoice fields from the attached document. Return JSON: {vendorName, invoiceNo, date, totalAmount, currency}.",
  "prompt": "Extract the invoice fields.",
  "attachment": {
    "table": "Incoming Document Attachment",
    "systemId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

#### Dæmi — Skrá send beint

```json
{
  "system": "Summarise the attached document in three sentences.",
  "prompt": "Summarise it.",
  "file": {
    "data": "JVBERi0xLjQKJcfsj6IK...",
    "mimeType": "application/pdf",
    "fileName": "Contract.pdf"
  }
}
```

### Svarsnið

**Innihaldsgerð**: `text/json`

| Reitur | Tegund | Lýsing |
|--------|--------|--------|
| `status` | String | `"Success"` eða `"Error"` |
| `text` | String | Textinn úr framkvæmdinni. Alltaf til staðar þegar vel tekst til. |
| `reply` | String | Hrái `reply`-reitur veitandans. Til staðar þegar veitandinn skilar `reply`; `text` er þá afritað úr honum. |
| `error` | String | Villuboð. Aðeins til staðar þegar `status` er `"Error"`. |
| `hint` | String | Vísun á `Help.Implementation.Get` fyrir þessa skilaboðategund. Aðeins til staðar þegar `status` er `"Error"`. |

Eiginleikar sem veitandinn bætir við umfram `text` og `reply` fara óbreyttir í gegn, svo veitandi sem skilar tókenatalningu eða líkanaheiti heldur þeim í svarinu.

#### Svardæmi

```json
{
  "reply": "{\"invoiceNo\":\"4521\",\"date\":\"2025-03-15\",\"total\":1250.00}",
  "status": "Success",
  "text": "{\"invoiceNo\":\"4521\",\"date\":\"2025-03-15\",\"total\":1250.00}"
}
```

#### Villusvardæmi

```json
{
  "status": "Error",
  "error": "Enginn spjallveitandi stilltur. Settu upp Bifröst mállíkan með spjallveitanda.",
  "hint": "For usage details, call the \"Help.Implementation.Get\" message type with subject \"LLM.Prompt.Complete\"."
}
```

### Val á veitanda

Mállíkanið — og þar með veitandinn, grunnslóðin, líkanaheitið, tímamörkin, tókenamörkin og API-lykillinn — er leyst upp í þessari röð:

1. **Prófa**-hnekking af spjaldi Bifröst mállíkans, þegar próf er í gangi í yfirstandandi setu.
2. `roleCode`-gildið úr beiðninni, þegar það fylgir með. Óþekktur kóði er villa; ekki er fallið aftur á næsta skref.
3. **Kóði Bifröst mállíkans** á Bifröst notandauppsetningu sendandans.
4. Bifröst mállíkanið sem merkt er **Sjálfgefið**.
5. Ekkert fannst — `None`-veitandinn er notaður, hann tilkynnir að ekkert sé stillt og kallið fellur með `status: Error`.

Veitandinn sem leystur er upp er spurður `IsConfigured` áður en kvaðningin er send. Veitandi sem svarar `false` — Copilot sem ekki er virkjaður í **Copilot og gervigreind**, eða `None`-veitandinn — stöðvar kallið áður en nokkurt álag fer út úr Business Central.

API-lykillinn er lesinn úr Isolated Storage á fyrirtækjasviði: fyrst persónulegur lykill sendandans (`Bifrost_Chat_Usr_<SystemId mállíkans>_<öryggisauðkenni notanda>`), síðan sameiginlegi þjónustulykillinn (`Bifrost_Chat_Svc_<SystemId mállíkans>`). Copilot-veitandinn þarf engan lykil — hann notar tilföng í umsjón Microsoft.

### Töflutilvísun

**Tafla**: Bifrost Language Model ori (10035335)

| Nr. | Heiti | Tegund | Í aðallykli |
|-----|-------|--------|-------------|
| 1 | Kóði | Code[20] | Já |
| 2 | Lýsing | Text[100] | Nei |
| 10 | Hæfni | Blob (UTF-8 texti) | Nei |
| 11 | Sjálfgefið | Boolean | Nei |
| 12 | Spjallveitandi | Tegundasafn "Bifrost LangModel Prov. ori" | Nei |
| 20 | Grunnslóð | Text[250] | Nei |
| 21 | Líkan | Text[100] | Nei |
| 22 | Tímamörk (sekúndur) | Integer | Nei |
| 23 | Hámarksfjöldi tókena | Integer | Nei |
| 24 | Spjallslóð | Text[250] | Nei |
| 25 | Líkanaslóð | Text[250] | Nei |

Reiturinn **Hæfni** er ekki notaður af `LLM.Prompt.Complete`. Hann geymir hæfnitextann sem skotið er inn í gagnvirka Bifröst-spjallið.

### Aðgangsreglur

- Sendandinn verður að hafa heimildarsettið **Spjallhlið** (`BIFROST Chat ori`, 10035398), sem veitir skrifaðgang að töflunni `Chat Gate ori`. Útfærslan athugar `WritePermission` á þeirri töflu áður en beiðnin er lesin. Án þess fellur kallið með `status: Error` og ekkert er sent til veitandans.
- Spjallhliðið fylgir hvorki `BIFROST Bragi ori` né `BIFROST Bragi Rd ori`. Kerfisstjóri úthlutar því sérstaklega, á hvern notanda.
- Bifröst-leyfi er nauðsynlegt. Útfærslan kallar á `AssertIsLicensed()` áður en nokkuð er unnið.
- Aðeins skilaboðaútgáfa 1 er samþykkt. `AssertVersion1()` hafnar öðru.

### Villumeðhöndlun

| Aðstæður | `error` |
|----------|---------|
| Sendandi hefur ekki heimildarsettið Spjallhlið | `LLM kvaðningu hafnað: vantar 'Bifröst Chat' heimildasett.` |
| `prompt` vantar eða er tómt | `Reiturinn "prompt" er nauðsynlegur.` |
| `roleCode` samsvarar engu Bifröst mállíkani | `Bifröst mállíkan "%1" fannst ekki.` |
| Mállíkanið sem leyst var upp hefur engan stilltan veitanda | `Enginn spjallveitandi stilltur. Settu upp Bifröst mállíkan með spjallveitanda.` |
| Copilot er ekki virkjaður í Copilot og gervigreind | `Copilot er ekki virkjað fyrir Bifröst Chat. Biddu kerfisstjóra um að virkja það í Copilot og gervigreind.` |
| Skrá eða viðhengi er sent til Copilot-veitandans | `Copilot veitandi styður ekki skráarviðhengi. Notaðu ytri veitanda (OpenAI, Azure OpenAI, Anthropic) til að vinna úr skjölum.` |
| Veitandinn skilar `error`-eiginleika | Villuboð veitandans sjálfs. |
| Veitandinn skilar einhverju sem er ekki JSON | Hrái textinn frá veitandanum, skilað sem villuboðum. |
| Önnur skilaboðaútgáfa en 1, eða ekkert gilt leyfi | Bifröst Foundation kastar villunni áður en útfærslan keyrir. |

Allar villuleiðir skila HTTP 200 með `status: "Error"` í meginmálinu. Skilaboðategundin kastar aldrei ómeðhöndlaðri AL-villu vegna stillinga- eða inntaksvanda.

### Munur á LLM.Prompt.Complete og gagnvirku Bifröst-spjalli

| | LLM.Prompt.Complete | Bifröst-spjallreitur / Spjallgluggi |
|---|---|---|
| Tól | Engin | Allur MCP-verkfæraþjónninn |
| Kerfiskvaðning | Aðeins `system` frá sendanda | Ræsing, auðkenni, hæfni mállíkans og kerfiskvaðning notandans |
| Svar | Alltaf texti | Getur skilað verkfærakvaðningum sem leystar eru í fleiri lotum |
| Samtalsstaða | Engin | Varðveitt fyrir samtal í mörgum lotum |
| Inngangur | `tasks`-API, biðröð, MCP `call_message_type` | Business Central-viðmótið |
| Notkun | Sjálfvirk verk og leikbækur | Gagnvirk vinna á síðu |

---

## Heimildarsett

| Heimildarsett | Auðk. | Lýsing |
|---|---|---|
| Spjallhlið | 10035398 | Veitir RIMD á töfluna `Chat Gate ori`. Nauðsynlegt til að kalla á `LLM.Prompt.Complete` og til að opna Bifröst-spjallið. Úthlutað sérstaklega — það fylgir hvorugu settinu hér að neðan. |
| Bifröst Bragi | 10035404 | Fullur aðgangur að mállíkönum, hlutum Bifröst-spjallsins, Copilot-veitandanum og MCP-verkfæraþjóninum. Aðeins lesaðgangur að Spjallhliðinu. |
| Bifröst Bragi lestur | 10035405 | Lesaðgangur að sömu hlutum. Mállíkön má skoða en ekki breyta. |

---

## Tengd skjöl

- [Bragi Extensibility](../en-us/Bragi_Extensibility.md) — hvernig nýjum mállíkanaveitanda er bætt við
- Bifröst Foundation, *API Reference* — `tasks`-endapunkturinn, umslagið og biðröðin
- Bifröst Foundation, *Setup Reference* — Bifröst notandauppsetning og kerfiskvaðning hvers notanda
- Bifröst Foundation, *Extensibility Reference* — `Message Type ori`-tegundasafnið og `Msg Interface ori`-samningurinn

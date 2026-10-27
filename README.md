# CSV Studio

Native macOS-app (SwiftUI/AppKit, macOS 13+) om CSV-bestanden te bekijken, bewerken en om te zetten naar Linked Data (Turtle).

## Bouwen
Vereist Xcode of de Command Line Tools (`xcode-select --install`).

    cd CSVStudio
    ./build.sh

De app staat daarna in `build/CSV Studio.app`. Sleep hem naar Programma's.

## Functies
- CSV/TSV openen; scheidingsteken en tekenset (UTF-8, Windows-1252, ...) worden automatisch herkend.
- Cellen bewerken (dubbelklik, of klik + Return; Tab/Return gaan naar de volgende cel), rijen/kolommen toevoegen, verwijderen, dupliceren, sorteren, kolommen hernoemen (dubbelklik op koptekst), filter, kopiëren/plakken vanuit Excel, ongedaan maken.
- Bestand > Opslaan (⌘S) en Opslaan als… (⇧⌘S).
- Exporteren naar Excel (.xlsx, ⇧⌘E) of direct openen in Excel (⌥⌘E).
- Weergave "Linked Data" (⌘2): klasse van het werkblad, basis-URI, subject-sjabloon, per kolom een predicaat uit gangbare vocabulaires (RDF, RDFS, OWL, SKOS, DC Terms, FOAF, Schema.org, vCard, PROV, DCAT, DQV, ORG, GEO, LOCN, ADMS, SHACL) of een eigen CURIE/URI, datatype, taal en scheidingsteken voor meerwaardige cellen. Live Turtle-voorbeeld en export naar .ttl (⇧⌘T).

# 11/35 for iPhone and Mac

Native SwiftUI application for iOS 17+ and macOS 14+. The Xcode project is `EuroAuto.xcodeproj`.

## What is in this first build

- Native adaptive navigation for iPhone and Mac, with overview, vehicle records, and customers.
- Local SwiftData storage configured for automatic CloudKit sync.
- Vehicle record fields for stock/customer imports, delivery, customs costs, sale price, and vehicle status.
- Searchable offline make/model/generation/engine selectors backed by the bundled catalog.
- Specification autofill from the selected engine, including displacement, power, fuel, drive, transmission, dimensions, wheelbase, and weight.
- Per-vehicle document import for PDF/JPG/PNG/WebP, up to 20 MB per file. Document bytes are stored with the local SwiftData record so the file remains available offline and can sync through the configured iCloud container.
- Full JSON backup and restore for customer records, vehicle fields, expenses, order details, and embedded document files. Restore matches customers by customer ID and vehicles by VIN, updates matches, and preserves unrelated existing records.
- Local purchase-cost, total-cost, and expected-profit calculations.
- Calcus customs calculations from the vehicle card. Both the client ID and API key are stored in the device-local Keychain and excluded from SwiftData records and JSON backups. Each user-triggered calculation sends one paid request; applying a result requires confirmation and updates the vehicle's customs expenses.

## Open and run on a Mac

1. Open `EuroAuto.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, choose the Apple development team and configure the iCloud container `iCloud.com.nordauto.euroauto` for that team. Automatic SwiftData sync needs the iCloud/CloudKit capability and optional model relationships.
3. Run the `EuroAuto` scheme on **My Mac** or an iPhone simulator. To install on an iPhone, connect it and select it as the run destination.
4. Verify offline entry, catalog lookup, document import/open, and costs on both targets. CloudKit requires internet to sync; local records and imported document bytes remain available offline.

The current workspace is Linux and has no Xcode, so Apple-target compilation, simulator runs, signing, and device verification have not been performed here.

## Data and transition

The catalog is copied from `../data/vehicle-catalog.json`; source and attribution are bundled in `EuroAuto/Resources/VEHICLE-CATALOG-SOURCE.md`. The website now has local source for a full JSON export, including available server files and documents already downloaded to the current browser. Importing that archive into the native app is implemented. The new export control still needs to be published and tested against the signed-in website before any live data is moved. Do not switch off the current data source until an export/import has been written and verified.

The app's bundle identifier and CloudKit container are starter values. Set them to identifiers owned by the Apple developer team before enabling production sync.

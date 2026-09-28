# Firebase environment and Android signing status

## Firebase projects

- Production: `homigo-care-76e21`
- Development: `homigo-care-dev-76e21`
- Android package: `pk.homigocare.android`

## Development signing fingerprints

The development Android app uses separate keys from production to avoid Firebase package/SHA collisions.

- Dev Debug SHA-1: `E0:75:5E:5E:CC:34:B4:F0:CB:D7:73:3B:6C:73:49:F2:FD:0C:6E:2A`
- Dev Debug SHA-256: `A4:48:15:32:9D:28:8A:F3:F4:1B:66:C6:00:B6:8B:E3:A6:DF:4E:E7:6D:07:34:73:B0:EB:D0:19:C0:C0:B6:FC`
- Dev Release SHA-1: `DF:8B:ED:09:D6:AE:7E:A4:25:45:E3:59:1F:22:0A:9C:9F:1F:92:50`
- Dev Release SHA-256: `08:25:65:E9:68:35:87:DC:CA:6A:FA:10:C2:21:C3:D2:34:82:06:A4:6E:17:F1:B9:2A:88:E4:7A:9F:24:EA:5F`

All four development fingerprints were registered on the Firebase development Android app.

## Media storage

Firebase Storage is not used. Images, videos, PDFs, CNICs, documents, prescriptions, receipts, and other files use Cloudinary only.

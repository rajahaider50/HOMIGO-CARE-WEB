# Cloudinary-only media storage

Cloudinary is the sole media/document store for HomigoCare. Use `homigo_public_assets` for public app assets and `homigo_user_documents` for signed user documents. Never import Firebase Storage SDKs or add Firebase Storage rules. The Cloudinary API secret is server-side only in the Admin/API deployment; mobile and browser clients request signed upload parameters from the trusted API.

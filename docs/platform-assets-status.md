# Platform asset installation

The 2026-09-28 `assets.zip` supplied four separate platform bundles. Android and iOS PNGs were installed under their platform asset directories. Web and Admin supplied 20 JPEG illustrations each; their manifests point to the exact installed files under `public/illustrations/`.

The archive contains no replacement HomigoCare master logo, launcher icon, favicon, adaptive-icon foreground, or background. Therefore the existing founder-provided brand icon remains authoritative and was not deleted or replaced. A new launcher/logo file must be supplied separately before changing those files.

Firebase Storage is not used; these are app assets intended for local/static delivery or Cloudinary public app assets.

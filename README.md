# ColdWhite 0.6.0

Preference Bundle is retained from the working 0.5.0 structure. The display backend is experimental: it uses iOS Accessibility Color Tint preferences because arbitrary global white-balance control is not exposed by a public iOS API.

0 = factory color. Higher values apply a subtle cool blue/cyan tint. Private preference keys can vary by iOS build, so this is experimental rather than guaranteed.

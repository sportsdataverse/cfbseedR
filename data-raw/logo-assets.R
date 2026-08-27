# Regenerate the raster logos and pkgdown/favicon/* from man/figures/logo.svg.
#
# man/figures/logo.svg is the source of truth. This script renders the two
# raster sizes used across the SportsDataverse hex family (518x600, and
# 1036x1200 for retina/print, matching cfbfastR) plus the favicon set. The hex
# is taller than it is wide, so each square favicon is the hex rendered at the
# target height and centered on a transparent square canvas.
#
# Run after any change to the logo: Rscript data-raw/favicons.R

library(magick)

svg <- "man/figures/logo.svg"

# raster logos
for (px in c(518, 1036)) {
  out <- if (px == 518) "man/figures/logo.png" else "man/figures/logo-2x.png"
  image_write(image_read_svg(svg, width = px), out, format = "png")
  cat("wrote", out, "\n")
}

square <- function(px) {
  img <- image_read_svg(svg, height = px)
  image_extent(img, paste0(px, "x", px), gravity = "center", color = "none")
}

write_png <- function(px, out) {
  image_write(square(px), out, format = "png")
  cat("wrote", out, "\n")
}

write_png(180, "pkgdown/favicon/apple-touch-icon.png")
write_png(96, "pkgdown/favicon/favicon-96x96.png")
write_png(192, "pkgdown/favicon/web-app-manifest-192x192.png")
write_png(512, "pkgdown/favicon/web-app-manifest-512x512.png")

base <- square(48)
ico <- c(image_scale(base, "16x16"), image_scale(base, "32x32"), base)
image_write(ico, "pkgdown/favicon/favicon.ico", format = "ico")
cat("wrote pkgdown/favicon/favicon.ico\n")

file.copy(svg, "pkgdown/favicon/favicon.svg", overwrite = TRUE)
cat("wrote pkgdown/favicon/favicon.svg\n")

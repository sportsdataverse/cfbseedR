# Regenerate pkgdown/favicon/* from man/figures/logo.svg.
#
# The hex is taller than it is wide, so each square favicon is the hex
# rendered at the target height and centered on a transparent square canvas.
# Run after any change to the logo: Rscript data-raw/favicons.R

library(magick)

svg <- "man/figures/logo.svg"

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

# hexSticker prototype for the cfbseedR logo.
#
# NOTE: `man/figures/logo.svg` is the SOURCE OF TRUTH for the shipped logo,
# and `data-raw/logo-assets.R` renders every raster from it (logo.png,
# logo-2x.png, the favicon set). This script is the original hexSticker
# exploration and is kept for reference only -- it is NOT what produces the
# shipped artwork, so do not expect its output to match. Keep the palette and
# `h_size` here in step with the SVG if you change either.
#
# Border thickness: hexSticker's `h_size` maps to roughly
# `border_px = 10 * h_size - 3` at the default 518px width (measured on this
# machine, R 4.6.1 / ragg). `h_size = 1.2` therefore gives the 9px border the
# SVG now draws, matching wehoop -- the thinnest ring in the family
# (sportsdataverse-R 11px, fastRhockey 17px).
#
# Ensure required packages are installed
# install.packages(c("ggplot2", "hexSticker", "showtext"))

library(ggplot2)
library(hexSticker)
library(showtext)

# 1. Define Color Palette
palette <- list(
  bg_id        = "#0f172a",  # Midnight slate
  border_id    = "#ffb703",  # Crisp gold
  text_id      = "#FFFFFF",  # Pure white
  bracket_line = "#475569",  # Clean slate grey for the bracket lines
  seed_node    = "#90e0ef",  # Electric blue for initial team slots
  champ_node   = "#ffb703"   # Gold for the crowning center node
)

# 2. Handle Typography
font_add_google("Ubuntu Mono", "ubuntu_mono")
showtext_auto()

# 3. Construct Explicit Symmetrical 12-Team Bracket Coordinates
# -------------------------------------------------------------
# Total teams: 8 playing in Round 1 + 4 First-Round Bye Teams = 12 Teams.
# -------------------------------------------------------------
bracket_segments <- data.frame(
  x = c(
    # LEFT SIDE: Round 1 (Seeds 5-12 matchups)
    -3.5, -3.5, -2.7, -2.7,
    -3.5, -3.5, -2.7, -2.7,
    # LEFT SIDE: Round 2 (Quarterfinals vs Byes)
    -2.0, -2.5, -1.5, -1.5,
    -2.5, -2.0, -1.5, -1.5,
    # LEFT SIDE: Round 3 (Semifinals)
    -0.7, -0.7,

    # RIGHT SIDE: Round 1 (Seeds 5-12 matchups)
    3.5, 3.5, 2.7, 2.7,
    3.5, 3.5, 2.7, 2.7,
    # RIGHT SIDE: Round 2 (Quarterfinals vs Byes)
    2.0, 2.5, 1.5, 1.5,
    2.5, 2.0, 1.5, 1.5,
    # RIGHT SIDE: Round 3 (Semifinals)
    0.7, 0.7
  ),
  y = c(
    # Left R1
    2, 1, 1, 1.5,
    6, 5, 5, 5.5,
    # Left R2
    1.5, 3.5, 1.5, 2.5,
    4.5, 5.5, 4.5, 5.0,
    # Left Semis
    2.5, 3.75,

    # Right R1
    2, 1, 1, 1.5,
    6, 5, 5, 5.5,
    # Right R2
    1.5, 3.5, 1.5, 2.5,
    4.5, 5.5, 4.5, 5.0,
    # Right Semis
    2.5, 3.75
  ),
  xend = c(
    # Left R1
    -2.7, -2.7, -2.7, -2.0,
    -2.7, -2.7, -2.7, -2.0,
    # Left R2
    -1.5, -1.5, -1.5, -0.7,
    -1.5, -1.5, -1.5, -0.7,
    # Left Semis
    -0.7, 0.0,

    # Right R1
    2.7, 2.7, 2.7, 2.0,
    2.7, 2.7, 2.7, 2.0,
    # Right R2
    1.5, 1.5, 1.5, 0.7,
    1.5, 1.5, 1.5, 0.7,
    # Right Semis
    0.7, 0.0
  ),
  yend = c(
    # Left R1
    2, 1, 2, 1.5,
    6, 5, 6, 5.5,
    # Left R2
    1.5, 3.5, 3.5, 2.5,
    4.5, 5.5, 5.5, 5.0,
    # Left Semis
    5.0, 3.75,

    # Right R1
    2, 1, 2, 1.5,
    6, 5, 6, 5.5,
    # Right R2
    1.5, 3.5, 3.5, 2.5,
    4.5, 5.5, 5.5, 5.0,
    # Right Semis
    5.0, 3.75
  )
)

# Points where initial seeds enter the bracket (Exactly 12 entry points)
seed_nodes <- data.frame(
  x = c(-3.5, -3.5, -3.5, -3.5, -2.5, -2.5,  3.5,  3.5,  3.5,  3.5,  2.5,  2.5),
  y = c(   1,    2,    5,    6,  3.5,  4.5,    1,    2,    5,    6,  3.5,  4.5)
)

# The ultimate national championship pinnacle node right in the dead center
champ_node <- data.frame(x = 0, y = 3.75)

# 4. Render Bracket Layout via ggplot
centerpiece <- ggplot() +
  # Draw crisp structural tree lines
  geom_segment(
    data = bracket_segments,
    aes(x = x, y = y, xend = xend, yend = yend),
    color = palette$bracket_line,
    linewidth = 1.0,
    lineend = "round"
  ) +
  # Draw the 12 initial team seed slots
  geom_point(
    data = seed_nodes,
    aes(x = x, y = y),
    color = palette$seed_node,
    size = 2.2
  ) +
  # Highlight the final champion vertex point
  geom_point(
    data = champ_node,
    aes(x = x, y = y),
    color = palette$champ_node,
    size = 4.5,
    shape = 18
  ) +
  # Establish clear visual boundaries with breathing room
  scale_x_continuous(limits = c(-4.2, 4.2)) +
  scale_y_continuous(limits = c(0.2, 6.8)) +
  theme_void() +
  theme(
    panel.background = element_blank(),
    plot.background = element_blank()
  )

# 5. Build and Save Hex Sticker
sticker(
  subplot = centerpiece,
  package = "cfbseedR",

  # Subplot placement (centered, sitting nicely below the package text)
  s_x = 1.0,
  s_y = 0.82,
  s_width = 1.45,
  s_height = 0.85,

  # Package text styling
  p_x = 1.0,
  p_y = 1.42,
  p_color = palette$text_id,
  p_family = "ubuntu_mono",
  p_size = 24,

  # Frame layout configuration
  h_fill = palette$bg_id,
  h_color = palette$border_id,
  h_size = 1.2,

  # Writes beside this script, NOT to man/figures/logo.png -- running the
  # prototype must never clobber the shipped logo rendered from logo.svg.
  filename = "data-raw/hexsticker-prototype.png"
)

showtext_auto(FALSE)

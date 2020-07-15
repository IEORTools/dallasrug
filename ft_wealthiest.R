library(tidyverse)

wealth <- tibble(
  name = c(
    "Jeff Bezos", "Bill Gates", "Mark Zuckerberg", "Bernard Arnault", "Steve Ballmer",
    "Larry Page", "Elon Musk",
    "Sergey Brin", "Mukesh Ambani", "Warren Buffet"
  ),
  worth = c(184, 115, 94.5, 90.8, 74.6, 72.4, 71.6, 69.7, 69.4, 68.6),
  increase = c(0.65, 0.4, 0.18, -0.11, .36, .14, 1.53, .13, .19, -0.21)
) %>%
  mutate(
    old_worth = round(worth / (increase + 1), digits = 1),
    font_face_bold = if_else(name == "Elon Musk", "bold", "plain"),
    name = fct_reorder(name, worth)
  )
wealth$increase_pct <- 100*wealth$increase

p <- ggplot(wealth, aes(x=name, y=worth, fill=increase_pct)) +
  geom_bar(stat="identity") +
  coord_flip() +
  geom_text(aes(y=20, label=paste(increase_pct,"%"))) +
  ggtitle("Top Ten Wealthiest Individuals") +
  ylab("Net Worth ($B)")

ggsave("ft_wealthiest.png", p, height = 6, width = 10, units = "in", dpi = "retina")

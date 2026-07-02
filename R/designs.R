draw_hospitals_R <- function(index0, index1, allocation) {
  list(
    s0 = sample(index0, allocation[[1]], replace = FALSE),
    s1 = sample(index1, allocation[[2]], replace = FALSE)
  )
}

rmvhyper_seq <- function(counts, n) {
  counts <- as.integer(counts)
  out <- integer(length(counts))
  remain_n <- n
  remain_N <- sum(counts)
  for (i in seq_len(length(counts) - 1L)) {
    out[i] <- rhyper(1, counts[i], remain_N - counts[i], remain_n)
    remain_n <- remain_n - out[i]
    remain_N <- remain_N - counts[i]
  }
  out[length(counts)] <- remain_n
  out
}

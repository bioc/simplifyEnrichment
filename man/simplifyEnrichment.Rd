\name{simplifyEnrichment}
\alias{simplifyEnrichment}
\title{
Simplify functional enrichment results
}
\description{
Simplify functional enrichment results
}
\usage{
simplifyEnrichment(mat, method = "binary_cut", control = list(),
    plot = TRUE, verbose = TRUE,
    column_title = qq("@{nrow(mat)} terms clustered by '@{method}'"),
    ht_list = NULL, ...)
}
\arguments{

  \item{mat}{A similarity matrix.}
  \item{method}{Method for clustering the matrix. See \code{\link{cluster_terms}}.}
  \item{control}{A list of parameters for controlling the clustering method, passed to \code{\link{cluster_terms}}.}
  \item{plot}{Whether to make the heatmap.}
  \item{column_title}{Column title for the heatmap.}
  \item{verbose}{Whether to print messages.}
  \item{ht_list}{A list of additional heatmaps added to the left of the similarity heatmap.}
  \item{...}{Arguments passed to \code{\link{ht_clusters}}.}

}
\details{
The usage is the same as \code{\link{simplifyGO}}.
}
\examples{
# There is no example
NULL

}

#' @keywords internal
"_PACKAGE"

#' MPAQT: Multi-Platform Aggregation and Quantification of Transcripts
#'
#' RNA-seq quantification pipeline integrating short-read and long-read
#' sequencing data for improved transcript abundance estimation. Supports
#' both bulk and single-cell RNA-seq analysis.
#'
#' @section Main Functions:
#' \describe{
#'   \item{\code{\link{mpaqt_index}}}{Create reference index from transcriptome and GTF}
#'   \item{\code{\link{mpaqt_quant_bulk}}}{Quantify bulk RNA-seq samples}
#'   \item{\code{\link{mpaqt_quant_sc}}}{Quantify single-cell RNA-seq samples}
#' }
#'
#' @section Algorithm:
#' MPAQT uses an EM algorithm to estimate transcript abundances by maximizing:
#'
#' \deqn{L(\beta) = L_{SR}(\beta) + L_{LR}(\beta) - R(\beta)}
#'
#' Where:
#' \itemize{
#'   \item \eqn{L_{SR}}: Short-read likelihood (equivalence class model)
#'   \item \eqn{L_{LR}}: Long-read likelihood (transcript-level, optional)
#'   \item \eqn{R}: L2 regularization penalty
#' }
#'
#' Key features include:
#' \itemize{
#'   \item Positional bias correction (3' or 5' end)
#'   \item Mixed-effects prior integration via gpboost
#'   \item Newton-Raphson optimization for transcript updates
#' }
#'
#' @section System Requirements:
#' MPAQT requires the following external tools:
#' \itemize{
#'   \item kallisto (>= 0.50.1) - \url{https://pachterlab.github.io/kallisto/}
#'   \item bustools (>= 0.43.1) - \url{https://bustools.github.io/}
#' }
#'
#' @name mpaqt-package
#' @aliases mpaqt
#'
#' @importFrom data.table data.table setDT fread fwrite `:=` .N .SD rbindlist
#'     as.data.table setnames dcast melt setcolorder
#' @importFrom Matrix sparseMatrix rowSums colSums t crossprod
#' @importFrom stats quantile glm poisson coefficients logLik optimize optim
#'     aggregate fitted cor model.matrix predict median setNames
#' @importFrom utils flush.console head
#' @importFrom methods as
#' @importFrom rlang `%||%`
NULL

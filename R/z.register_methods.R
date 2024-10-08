
.ENV = new.env()
.ENV$ALL_CLUSTERING_FUN = list()
.ENV$ALL_CLUSTERING_METHODS = NULL

get_clustering_method = function(method, control = list()) {
	if(!method %in% .ENV$ALL_CLUSTERING_METHODS) {
		stop_wrap(qq("Clustering method '@{method}' has not been defined yet."))
	}
	fun = .ENV$ALL_CLUSTERING_FUN[[method]]

	fun2 = function(mat) {
		cl = do.call(fun, c(list(mat), control))
		if(is.atomic(cl)) {
			if(length(cl) != nrow(mat)) {
				stop_wrap("Length of clusterings should be the same as number of matrix rows.")
			}
		} else {
			stop_wrap(qq("Clustering method '@{method}' should return an atomic vector."))
		}
		cl = as.numeric(as.factor(cl))

		return(cl)
	}
	
	return(fun2)
}

#' Configure clustering methods
#'
#' @param ... A named list of clustering functions, see in **Details**.
#'
#' @details
#' The user-defined functions should accept at least one argument which is the input matrix. 
#' The second optional argument should always be `...` so that parameters
#' for the clustering function can be passed by the `control` argument from [`cluster_terms()`], [`simplifyGO()`] or [`simplifyEnrichment()`].
#' If users forget to add `...`, it is added internally.
#'
#' Please note, the user-defined function should automatically identify the optimized
#' number of clusters.
#'
#' The function should return a vector of cluster labels. Internally it is converted to numeric labels.
#'
#' @rdname cluster_methods
#' @export
#' @examples
#' register_clustering_methods(
#'     # assume there are 5 groups
#'     random = function(mat, ...) sample(5, nrow(mat), replace = TRUE)
#' )
#' all_clustering_methods()
#' remove_clustering_methods("random")
register_clustering_methods = function(...) {
	
	lt = list(...)
	lt = lapply(lt, function(fun) {
		# just in case people forgot to add the ...
		if(length(formals(fun)) == 1) {
			function(mat, ...) {
				fun(mat)
			}
		} else {
			fun
		}
	})
	lt1 = lt[intersect(names(lt), .ENV$ALL_CLUSTERING_METHODS)]
	lt2 = lt[setdiff(names(lt), .ENV$ALL_CLUSTERING_METHODS)]
	if(length(lt1)) .ENV$ALL_CLUSTERING_FUN[names(lt1)] = lt1
	if(length(lt2)) .ENV$ALL_CLUSTERING_FUN = c(.ENV$ALL_CLUSTERING_FUN, lt2)
	.ENV$ALL_CLUSTERING_METHODS = names(.ENV$ALL_CLUSTERING_FUN)
}

#' @details
#' The default clustering methods are:
#'
#' - `kmeans` see [`cluster_by_kmeans()`].
#' - `dynamicTreeCut` see [`cluster_by_dynamicTreeCut()`].
#' - `mclust` see [`cluster_by_mclust()`].
#' - `apcluster` see [`cluster_by_apcluster()`].
#' - `hdbscan` see [`cluster_by_hdbscan()`].
#' - `fast_greedy` see [`cluster_by_fast_greedy()`].
#' - `louvain` see [`cluster_by_louvain()`].
#' - `walktrap` see [`cluster_by_walktrap()`].
#' - `MCL` see [`cluster_by_MCL()`].
#' - `binary_cut` see [`binary_cut()`].
#'
#' @returns
#' `all_clustering_methods()` returns a vector of clustering method names.
#' @export
#' @rdname cluster_methods
all_clustering_methods = function() {
	x = .ENV$ALL_CLUSTERING_METHODS
	return(x)
}

#' @param method A vector of method names.
#' @export
#' @rdname cluster_methods
remove_clustering_methods = function(method) {
	nm_keep = setdiff(.ENV$ALL_CLUSTERING_METHODS, method)
	.ENV$ALL_CLUSTERING_FUN = .ENV$ALL_CLUSTERING_FUN[nm_keep]
	.ENV$ALL_CLUSTERING_METHODS = nm_keep
}

register_clustering_methods(
	binary_cut = function(mat, ...) binary_cut(mat, ...),
	kmeans = function(mat, ...) cluster_by_kmeans(mat, ...),
	pam = function(mat, ...) cluster_by_pam(mat, ...),
	dynamicTreeCut = function(mat, ...) cluster_by_dynamicTreeCut(mat, ...),
	mclust = function(mat, ...) cluster_by_mclust(mat, ...),
	apcluster = function(mat, ...) cluster_by_apcluster(mat, ...),
	hdbscan = function(mat, ...) cluster_by_hdbscan(mat, ...),
	fast_greedy = function(mat, ...) cluster_by_fast_greedy(mat, ...),
	louvain = function(mat, ...) cluster_by_louvain(mat, ...),
	walktrap = function(mat, ...) cluster_by_walktrap(mat, ...),
	MCL = function(mat, ...) cluster_by_MCL(mat, ...)
)

#' @rdname cluster_methods
#' @export
#' @examples
#' all_clustering_methods()
#' remove_clustering_methods(c("kmeans", "mclust"))
#' all_clustering_methods()
#' reset_clustering_methods()
#' all_clustering_methods()
reset_clustering_methods = function() {
	remove_clustering_methods(all_clustering_methods())
	register_clustering_methods(
		kmeans = function(mat, ...) cluster_by_kmeans(mat, ...),
		pam = function(mat, ...) cluster_by_pam(mat, ...),
		dynamicTreeCut = function(mat, ...) cluster_by_dynamicTreeCut(mat, ...),
		mclust = function(mat, ...) cluster_by_mclust(mat, ...),
		apcluster = function(mat, ...) cluster_by_apcluster(mat, ...),
		hdbscan = function(mat, ...) cluster_by_hdbscan(mat, ...),
		fast_greedy = function(mat, ...) cluster_by_fast_greedy(mat, ...),
		louvain = function(mat, ...) cluster_by_louvain(mat, ...),
		walktrap = function(mat, ...) cluster_by_walktrap(mat, ...),
		MCL = function(mat, ...) cluster_by_MCL(mat, ...),
		binary_cut = function(mat, ...) binary_cut(mat, ...)
	)
}

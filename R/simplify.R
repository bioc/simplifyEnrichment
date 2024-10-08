

#' Simplify Gene Ontology (GO) enrichment results
#'
#' @param mat A GO similarity matrix. You can also provide a vector of GO IDs to this argument.
#' @param method Method for clustering the matrix. See [`cluster_terms()`].
#' @param control A list of parameters for controlling the clustering method, passed to [`cluster_terms()`].
#' @param plot Whether to make the heatmap.
#' @param column_title Column title for the heatmap.
#' @param verbose Whether to print messages.
#' @param ht_list A list of additional heatmaps added to the left of the similarity heatmap.
#' @param ... Arguments passed to [`ht_clusters()`].
#'
#' @details
#' This is basically a wrapper function that it first runs [`cluster_terms()`] to cluster
#' GO terms and then runs [`ht_clusters()`] to visualize the clustering.
#'
#' The arguments in `simplifyGO()` passed to `ht_clusters()` are:
#'
#' - `draw_word_cloud`: Whether to draw the word clouds.
#' - `min_term`: Minimal number of GO terms in a cluster. All the clusters
#'     with size less than `min_term` are all merged into one single cluster in the heatmap.
#' - `order_by_size`: Whether to reorder GO clusters by their sizes. The cluster
#'      that is merged from small clusters (size < `min_term`) is always put to the bottom of the heatmap.
#' - `stat`: What values of keywords are used to map to font sizes in the word clouds.
#' - `exclude_words`: Words that are excluded in the word cloud.
#' - `max_words`: Maximal number of words visualized in the word cloud.
#' - `word_cloud_grob_param`: A list of graphic parameters passed to [`word_cloud_grob()`].
#' - `fontsize_range` The range of the font size. The value should be a numeric vector with length two.
#'       The minimal font size is mapped to word frequency value of 1 and the maximal font size is mapped
#'       to the maximal word frequency. The font size interlopation is linear.
#' - `bg_gp`: Graphic parameters for controlling the background of word cloud annotations.
#'
#' @return
#' A data frame with two columns: GO IDs and cluster labels.
#' @export
#' @examples
#' \donttest{
#' set.seed(123)
#' go_id = random_GO(500)
#' mat = GO_similarity(go_id)
#' df = simplifyGO(mat, word_cloud_grob_param = list(max_width = 80))
#' head(df)
#' }
simplifyGO = function(mat, method = "binary_cut", control = list(), 
	plot = TRUE, verbose = TRUE, 
	column_title = qq("@{nrow(mat)} GO terms clustered by '@{method}'"),
	ht_list = NULL, ...) {

	if(is.atomic(mat) && !is.matrix(mat)) {
		go_id = mat
		if(!all(grepl("^GO:\\d+$", go_id))) {
			stop_wrap("If you specify a vector, it should contain all valid GO IDs.")
		}

		mat = GO_similarity(go_id)
	}
	
	cl = do.call(cluster_terms, list(mat = mat, method = method, verbose = verbose, control = control))
	go_id = rownames(mat)
	if(is.null(go_id)) {
		go_id = colnames(mat)
	}

	if(!all(grepl("^GO:\\d+$", go_id))) {
		stop_wrap("Please ensure GO IDs are the row names of the similarity matrix and should be matched to '^GO:\\\\d+$'.")
	}

	if(plot) ht_clusters(mat, cl, column_title = column_title, ht_list = ht_list, ...)

	return(invisible(data.frame(id = go_id, cluster = cl, stringsAsFactors = FALSE)))
}


#' @export
#' @rdname simplifyGO
simplifyEnrichment = function(...) {
	message("From version 2.0.0, `simplifyEnrichment()` is identical to `simplifyGO()`.")
	simplifyGO(...)
}

#' Perform simplifyGO analysis with multiple lists of GO IDs
#'
#' @param lt A data frame, a list of numeric vectors (e.g. adjusted p-values) where each numeric vector has GO IDs as names, or a list of GO IDs.
#' @param go_id_column Column index of GO ID if `lt` contains a list of data frames.
#' @param padj_column Column index of adjusted p-values if `lt` contains a list of data frames.
#' @param padj_cutoff Cut off for adjusted p-values.
#' @param filter A self-defined function for filtering GO IDs. By default it requires GO IDs should be significant in at least one list.
#' @param default The default value for the adjusted p-values. See **Details**.
#' @param ont Pass to [`GO_similarity()`].
#' @param db Pass to [`GO_similarity()`].
#' @param measure Pass to [`GO_similarity()`].
#' @param heatmap_param Parameters for controlling the heatmap, see **Details**.
#' @param show_barplot Whether draw barplots which shows numbers of significant GO terms in clusters.
#' @param method Pass to [`simplifyGO()`].
#' @param control Pass to [`simplifyGO()`].
#' @param min_term Pass to [`simplifyGO()`].
#' @param verbose Pass to [`simplifyGO()`].
#' @param column_title Pass to [`simplifyGO()`].
#' @param ... Pass to [`simplifyGO()`].
#'
#' @details
#' The input data can have three types of formats:
#'
#' - A list of numeric vectors of adjusted p-values where each vector has the GO IDs as names.
#' - A data frame. The column of the GO IDs can be specified with `go_id_column` argument and the column of the adjusted p-values can be
#'      specified with `padj_column` argument. If these columns are not specified, they are automatically identified. The GO ID column
#'      is found by checking whether a column contains all GO IDs. The adjusted p-value column is found by comparing the column names of the 
#'      data frame to see whether it might be a column for adjusted p-values. These two columns are used to construct a numeric vector
#'      with GO IDs as names.
#' - A list of character vectors of GO IDs. In this case, each character vector is changed to a numeric vector where
#'   all values take 1 and the original GO IDs are used as names of the vector.
#'
#' Now let's assume there are `n` GO lists, we first construct a global matrix where columns correspond to the `n` GO lists and rows correspond
#' to the "union" of all GO IDs in the lists. The value for the ith GO ID and in the jth list are taken from the corresponding numeric vector
#' in `lt`. If the jth vector in `lt` does not contain the ith GO ID, the value defined by `default` argument is taken there (e.g. in most cases the numeric
#' values are adjusted p-values, `default` is set to 1). Let's call this matrix as `M0`.
#'
#' Next step is to filter `M0` so that we only take a subset of GO IDs of interest. We define a proper function via argument `filter` to remove
#' GO IDs that are not important for the analysis. Functions for `filter` is applied to every row in `M0` and `filter` function needs
#' to return a logical value to decide whether to remove the current GO ID. For example, if the values in `lt` are adjusted p-values, the `filter` function
#' can be set as `function(x) any(x < padj_cutoff)` so that the GO ID is kept as long as it is signfiicant in at least one list. After the filter, let's call
#' the filtered matrix `M1`.
#'
#' GO IDs in `M1` (row names of `M1`) are used for clustering. A heatmap of `M1` is attached to the left of the GO similarity heatmap so that
#' the group-specific (or list-specific) patterns can be easily observed and to corresponded to GO functions.
#'
#' Argument `heatmap_param` controls several parameters for heatmap `M1`:
#'
#' - `transform`: A self-defined function to transform the data for heatmap visualization. The most typical case is to transform adjusted p-values by `-log10(x)`.
#' - `breaks`: break values for color interpolation.
#' - `col`: The corresponding values for `breaks`.
#' - `labels`: The corresponding labels.
#' - `name`: Legend title.
#' @export
#' @examples
#' \donttest{
#' # perform functional enrichment on the signatures genes from cola anlaysis 
#' require(cola)
#' data(golub_cola) 
#' res = golub_cola["ATC:skmeans"]
#' require(hu6800.db)
#' x = hu6800ENTREZID
#' mapped_probes = mappedkeys(x)
#' id_mapping = unlist(as.list(x[mapped_probes]))
#' lt = functional_enrichment(res, k = 3, id_mapping = id_mapping) # you can check the value of `lt`
#'
#' # a list of data frames
#' simplifyGOFromMultipleLists(lt, padj_cutoff = 0.001)
#'
#' # a list of numeric values
#' lt2 = lapply(lt, function(x) structure(x$p.adjust, names = x$ID))
#' simplifyGOFromMultipleLists(lt2, padj_cutoff = 0.001)
#'
#' # a list of GO IDS
#' lt3 = lapply(lt, function(x) x$ID[x$p.adjust < 0.001])
#' simplifyGOFromMultipleLists(lt3)
#' }
simplifyGOFromMultipleLists = function(lt, go_id_column = NULL, 
	padj_column = NULL, padj_cutoff = 1e-2,
	filter = function(x) any(x < padj_cutoff), default = 1, 
	ont = NULL, db = 'org.Hs.eg.db', measure = "Sim_XGraSM_2013",
	heatmap_param = list(NULL), show_barplot = TRUE,
	method = "binary_cut", control = list(), 
	min_term = NULL, verbose = TRUE, column_title = NULL, ...) {

	n = length(lt)

	if(is.data.frame(lt[[1]])) {

		if(is.null(go_id_column)) {
			go_id_column = which(sapply(lt[[1]], function(x) all(grepl("^GO:\\d+$", x))))[1]
			if(length(go_id_column) == 0) {
				if(!is.null(rownames(lt[[1]]))) {
					go_id_column = rownames
					if(is.null(rownames(lt[[1]]))) {
						stop_wrap("Cannot find the GO ID column in the data frames. Please explicitly set argument `go_id_column`.")
					}
					if(verbose) {
						message_wrap("Use row names of the data frame as `go_id_column`.")
					}
				} else {
					stop_wrap("Cannot find the GO ID column in the data frames. Please explicitly set argument `go_id_column`.")
				}
			} else {
				if(verbose) {
					message_wrap(qq("Use column '@{colnames(lt[[1]])[go_id_column]}' as `go_id_column`."))
				}
			}
		}
		if(is.null(padj_column)) {
			cn = colnames(lt[[1]])
			ind = test_padj_column(cn)
			if(length(ind)) {
				padj_column = ind
				if(verbose) {
					message_wrap(qq("Use column '@{colnames(lt[[1]])[padj_column]}' as `padj_column`."))
				}
			} else {
				stop_wrap("Cannot find the column the contains adjusted p-values in the data frames. Please explicitly set argument `padj_column`.")
			}
		}

		lt = lapply(lt, function(x) {
			if(is.function(go_id_column)) {
				structure(x[, padj_column], names = go_id_column(x))
			} else {
				structure(x[, padj_column], names = x[, go_id_column])
			}
		})
		return(simplifyGOFromMultipleLists(lt, padj_cutoff = padj_cutoff, filter = filter, default = default, ont = ont, db = db, measure = measure, heatmap_param = heatmap_param, 
			show_barplot = show_barplot, method = method, 
			control = control, min_term = min_term, verbose = verbose, column_title = column_title, ...))
		
	} else if(is.character(lt[[1]])) {
		lt = lapply(lt, function(x) structure(rep(1, length(x)), names = x))
		return(simplifyGOFromMultipleLists(lt, default = 0, filter = function(x) TRUE, ont = ont, db = db, measure = measure, show_barplot = show_barplot,
			method = method,
			heatmap_param = list(transform = function(x) x, breaks = c(0, 1), col = c("transparent", "red"), name = "", labels = c("not available", "available")),
			control = control, min_term = min_term, verbose = verbose, column_title = column_title, ...))
	}

	heatmap_param2 = list(transform = NULL, 
		breaks = NULL, col = NULL, labels = NULL, name = "padj"
	)
	for(nm in names(heatmap_param)) {
		heatmap_param2[[nm]] = heatmap_param[[nm]]
	}

	transform = heatmap_param2$transform
	if(is.null(transform)) transform = function(x) -log10(x)
	breaks = heatmap_param2$breaks
	col = heatmap_param2$col
	labels = heatmap_param2$labels
	name = heatmap_param2$name
	if(is.null(name)) name = ""

	if(is.null(breaks) && is.null(col)) {
		digit = ceiling(-log10(padj_cutoff))
		base = padj_cutoff*10^digit
		breaks = c(1, padj_cutoff, base*10^(-digit*2))
		col = c("green", "white", "red")
		labels = gt_render(c("1", qq("@{base}x10<sup>-@{digit}</sup>"), qq("@{base}x10<sup>-@{digit*2}</sup>")))
	} else if(!is.null(breaks) && !is.null(col)) {
		if(length(breaks) != length(col)) {
			stop_wrap("Length of `breaks` must be the same as the length of `col`.")
		}
	}

	all_go_id = unique(unlist(lapply(lt, names)))
	if(!all(grepl("^GO:\\d+$", all_go_id))) {
		stop_wrap("Only GO ID is allowed.")
	}

	m = matrix(default, nrow = length(all_go_id), ncol = n)
	rownames(m) = all_go_id
	colnames(m) = names(lt)
	if(is.null(colnames)) colnames = paste0("Group", 1:n)

	for(i in 1:n) {
		m[names(lt[[i]]), i] = lt[[i]]
	}

	l = apply(m, 1, function(x) {
		if(all(is.na(x))) {
			FALSE
		} else {
			l = filter(x[!is.na(x)])
			if(length(l) == 1) {
				return(l)
			} else {
				return(any(l))
			}
		}
	})
	m = m[l, , drop = FALSE]
	m = t(apply(m, 1, transform))

	if(verbose) message(qq("@{nrow(m)}/@{length(all_go_id)} GO IDs left for clustering."))

	if(length(unique(m[!is.na(m)])) <= 2) {
		col = structure(col, names = breaks)
	} else {
		if(is.null(breaks) && is.null(col)) {
			col = NULL
		} else if(!is.null(breaks) && !is.null(col)) {
			if(length(breaks) != length(col)) {
				stop_wrap("Length of `breaks` and `col` should be the same.")
			}
			col = colorRamp2(transform(breaks), col)
		} else {
			stop_wrap("Arguments `breaks` and `col` should be set at the same time.")
		}
	}

	all_go_id = rownames(m)
	sim_mat = GO_similarity(all_go_id, ont = ont, db = db, measure = measure)
	all_go_id = rownames(sim_mat)  # some GO ids might be removed

	heatmap_legend_param = list()
	heatmap_legend_param$at = transform(breaks)
	heatmap_legend_param$labels = if(is.null(labels)) breaks else labels
	heatmap_legend_param$title = name
	mm = m[all_go_id, , drop = FALSE]

	if(show_barplot) {
		draw_ht = function(align_to) {

			s = sapply(align_to, function(index) max(apply(mm[index, ], 2, function(x) sum(x >= transform(padj_cutoff)))))
			max = max(s)
			by = diff(grid.pretty(c(0, max)))[1]
			Heatmap(mm, col = col, name = if(name == "") NULL else name,
				show_row_names = FALSE, cluster_columns = FALSE,
				border = "black",
				heatmap_legend_param = heatmap_legend_param,
				width = unit(0.5, "cm")*n, use_raster = TRUE,
				left_annotation = rowAnnotation(
					empty = anno_block(width = unit(1.2, "cm"), panel_fun = function(index) grid.text(qq("Number of significant GO terms in each cluster (padj < @{padj_cutoff})"), unit(0, "npc"), 0.5, just = "top", rot = 90, gp = gpar(fontsize = 10))),
					bar = anno_link(
						align_to = align_to, side = "left", gap = unit(3, "mm"),
						link_gp = gpar(fill = "#DDDDDD", col = "#AAAAAA"), internal_line = FALSE,
						panel_fun = function(index) {
							v = apply(mm[index, ], 2, function(x) sum(x >= transform(padj_cutoff)))
							grid.text(v[2])
							pushViewport(viewport())
							grid.rect(gp = gpar(fill = "#DDDDDD", col = "#DDDDDD"))
							grid.lines(c(1, 0, 0, 1), c(0, 0, 1, 1), gp = gpar(col = "#AAAAAA"), default.units = "npc")
			    			pushViewport(viewport(xscale = c(0.5, length(v) + 0.5), yscale = c(0, max(v)), height = unit(1, "npc") - unit(2, "mm")))
							grid.rect(seq_along(v), 0, width = 0.6, height = unit(v, "native"), default.units = "native", just = "bottom", gp = gpar(fill = "#444444", col = "#444444"))
							if(length(index)/nrow(mm) > 0.05) {
								grid.yaxis(at = seq(0, max(v), by = by), gp = gpar(col = "#444444", cex = 0.6))
							}
							popViewport()
							popViewport()
						},
						size = s/sum(s)*(unit(1, "npc") - unit(3, "mm")*(length(align_to) - 1) - unit(2, "mm")*length(align_to)) + unit(2, "mm")
					)
				),
				post_fun = function(ht) {
					decorate_annotation("bar", {
						nc = ncol(mm)
						grid.text(colnames(mm), (seq_len(nc)-0.5)/nc*(unit(1, "npc") - unit(5, "mm")), y = -ht_opt$COLUMN_ANNO_PADDING, default.units = "npc", just = "right", rot = 90)
					})
				})
		}
	} else {
		draw_ht = Heatmap(mm, col = col, name = if(name == "") NULL else name,
				show_row_names = FALSE, cluster_columns = FALSE,
				border = "black",
				heatmap_legend_param = heatmap_legend_param,
				width = unit(0.5, "cm")*n, use_raster = TRUE)
	}

	
	if(is.null(min_term)) min_term = round(nrow(sim_mat)*0.02)
	if(is.null(column_title)) column_title = qq("@{length(all_go_id)} GO terms clustered by '@{method}'")

	simplifyGO(sim_mat, ht_list = draw_ht, method = method, 
		verbose = verbose, min_term = min_term, control = control, column_title = column_title, ...)
}

is_p_value = function(x) {
	if(!all(x <= 1 & x >= 0)) {
		return(FALSE)
	}
	v = -log10(x)
	if(sum(v > 2)/length(v) > 0.05) {
		TRUE
	} else {
		FALSE
	}
}

test_padj_column = function(cn) {
	test_cn = c("p.adjust", "p_adjust", "padjust", "padj", "fdr", "FDR", "BH", "p.value", "p-value", "pvalue", "p_value")
	for(x in test_cn) {
		ind = which(cn %in% x)
		if(length(ind)) {
			return(ind[1])
		}
	}
	return(NULL)
}

help_msg = function(fun) {
	
}


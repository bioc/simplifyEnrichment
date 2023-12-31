
env = new.env()
env$semData_hash = ""

# == title
# Calculate Gene Ontology (GO) semantic similarity matrix
#
# == param
# -go_id A vector of GO IDs.
# -ont GO ontology. Value should be one of "BP", "CC" or "MF". If it is not specified,
#      the function automatically identifies it by random sampling 10 IDs from ``go_id`` (see `guess_ont`).
# -db Annotation database. It should be from https://bioconductor.org/packages/3.10/BiocViews.html#___OrgDb. The value
#    can also directly be a ``OrgDb`` object.
# -measure Semantic measure for the GO similarity, pass to `GOSemSim::termSim`.
# -remove_orphan_terms Whether to remove terms that have zero similarity to all other terms?
#
# == details
# This function is basically a wrapper on `GOSemSim::termSim`.
#
# == value
# A symmetric matrix.
#
# == examples
# \donttest{
# go_id = random_GO(100)
# mat = GO_similarity(go_id)
# }
GO_similarity = function(go_id, ont = NULL, db = 'org.Hs.eg.db', measure = "Rel",
	remove_orphan_terms = FALSE) {

	if(is.null(ont)) {
		ont = guess_ont(go_id, db)
		if(is.null(ont)) {
			stop_wrap("Cannot determine which GO ontology (BP/CC/MF) you are using. Please manualy set `ont` argument.")
		}
		message(qq("You haven't provided value for `ont`, guess it as `@{ont}`."))
	}

	hash = digest::digest(list(ont = ont, db = db))
	if(hash == env$semData_hash) {
		semData = env$semData
	} else {
		suppressMessages(semData <- godata(db, ont = ont))
		env$semData_hash = hash
		env$semData = semData
	}
	go_removed = setdiff(go_id, Lkeys(getFromNamespace("getAncestors", "GOSemSim")(semData@ont)))

	if(length(go_removed)) {
		message(qq("@{length(go_removed)}/@{length(go_id)} GO term@{ifelse(length(go_removed) == 1, ' is', 's are')} removed."))
	}
	go_id = setdiff(go_id, go_removed)
	# go_sim = calc_similarity(go_id, measure = measure, semData = semData, mc.cores = mc.cores)
	go_sim = termSim(go_id, go_id, method = measure, semData = semData)
	go_sim[is.na(go_sim)] = 0

	go_sim[lower.tri(go_sim)]  = t(go_sim)[lower.tri(go_sim)]

	if(remove_orphan_terms) {
		go_sim_tmp = go_sim
		diag(go_sim_tmp) = 0
		l = rowSums(go_sim_tmp) == 0
		if(any(l)) {
			message(qq("@{sum(l)} GO term@{ifelse(sum(l) == 1, ' is', 's are')} removed because @{ifelse(sum(l) == 1, 'it has', 'they have')} zero similarity to all other terms."))
			go_sim = go_sim[l, l, drop = FALSE]
		}
	}

	attr(go_sim, "measure") = measure
	attr(go_sim, "ontology") = paste0("GO:", ont)
	return(go_sim)
}


split_by_block = function(n, size) {
	size = min(c(n, size))
	REST = n %% size
    LARGE = n - REST
    NBLOCKS = n %/% size
    GROUP = rep(1:NBLOCKS, each = size)
    if (REST > 0) GROUP = c(GROUP, rep(NBLOCKS + 1, REST))
    split(1:n, GROUP)
}

# # Don't think about it, SQLite does not allow multiple core
calc_similarity = function(go_id, measure, semData, verbose = TRUE) {

	go_removed = setdiff(go_id, Lkeys(getFromNamespace("getAncestors", "GOSemSim")(semData@ont)))

	if(length(go_removed)) {
		message(qq("@{length(go_removed)}/@{length(go_id)} GO term@{ifelse(length(go_removed) == 1, ' is', 's are')} removed."))
	}
	go_id = setdiff(go_id, go_removed)
	
	n = length(go_id)
	SPLIT = split_by_block(n, max(floor(sqrt(n)), 500))
	COMBS = expand.grid(1:length(SPLIT), 1:length(SPLIT))
	COMBS = t(apply(COMBS, 1, sort))
	COMBS = unique(COMBS)

	lt = lapply(seq_len(nrow(COMBS)), function(i) {
		if(verbose) message_wrap(qq("apply block [@{COMBS[i, 1]}, @{COMBS[i, 2]}] @{i}/@{nrow(COMBS)} (@{round(i/nrow(COMBS)*100, 1)}%)"))
		ind1 = SPLIT[[ COMBS[i, 1] ]]
		ind2 = SPLIT[[ COMBS[i, 2] ]]
		invisible(termSim(go_id[ind1], go_id[ind2], method = measure, semData = semData))
	})

	m = matrix(nrow = n, ncol = n)
	dimnames(m) = list(go_id, go_id)
	for(i in seq_len(nrow(COMBS))) {
		ind1 = SPLIT[[ COMBS[i, 1] ]]
		ind2 = SPLIT[[ COMBS[i, 2] ]]
		if(COMBS[i, 1] == COMBS[i, 2]) {
			m[ind1, ind2] = lt[[i]]
		} else {
			m[ind1, ind2] = lt[[i]]
			m[ind2, ind1] = lt[[i]]
		}
	}
	return(m)
}

# == title
# Guess the ontology of the input GO IDs
#
# == param
# -go_id A vector of GO IDs.
# -db Annotation database. It should be from https://bioconductor.org/packages/3.10/BiocViews.html#___OrgDb. The value
#    can also directly be a ``OrgDb`` object.
#
# == details
# 10 GO IDs are randomly sampled and checked.
#
# == value
# A single character scalar of "BP", "CC" or "MF".
#
# If there are more than one ontologies detected. It returns ``NULL``.
#
# == examples
# \donttest{
# go_id = random_GO(100)
# guess_ont(go_id)
# }
guess_ont = function(go_id, db = 'org.Hs.eg.db') {

	if(is.character(db)) {
		db = get(db, asNamespace(db))
	}
	test_go_id = sample(go_id, min(c(length(go_id), 10)))
	suppressMessages(df <- select(db, keys = test_go_id, columns = "ONTOLOGY", keytype = "GO"))
	guess_ont = unique(df$ONTOLOGY)
	guess_ont = guess_ont[!is.na(guess_ont)]
	if(length(guess_ont) != 1) {
		return(NULL)
	} else {
		return(guess_ont)
	}
}

# == title
# Generate random GO IDs
#
# == param
# -n Number of GO IDs.
# -ont GO ontology. Value should be one of "BP", "CC" or "MF".
# -db Annotation database. It should be from https://bioconductor.org/packages/3.10/BiocViews.html#___OrgDb
#
# == value
# A vector of GO IDs.
#
# == examples
# \donttest{
# random_GO(100)
# }
random_GO = function(n, ont = "BP", db = 'org.Hs.eg.db') {
	hash = digest::digest(list(ont = ont, db = db))
	if(hash == env$semData_hash) {
		semData = env$semData
	} else {
		suppressMessages(semData <- godata(db, ont = ont))
		env$semData_hash = hash
		env$semData = semData
	}

	all_go_id = unique(semData@geneAnno$GO)

	sample(all_go_id, min(n, length(all_go_id)))
}

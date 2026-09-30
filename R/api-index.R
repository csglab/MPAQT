# API: Index creation
# Main user-facing function for creating MPAQT index

# Declare data.table column names to avoid R CMD check NOTEs
# The '.' is used by data.table for j-expression grouping
utils::globalVariables(c(".",
    "tr_id", "gene_id", "transcript_type", "gene_type", "type",
    "transcript_id", "tr_seq", "tr_len", "gc_ratio", "is_protein_coding",
    "has_polyA", "num_reads", "cumsum_reads", "chunk", "read_id_start",
    "read_id_end", "start", "end", "read_id", "dist_5p", "dist_3p",
    "ec_id", "ec_tr_id", "N", "ec_idx", "tr_idx", "count",
    "sum_dist_5p", "sum_dist_3p", "total_count", "gene_idx"
))

#' Create MPAQT Index
#'
#' Build a comprehensive index for transcript quantification. Supports multiple
#' input pathways:
#' - **Pathway A**: GTF + FASTA - Build index from transcriptome file
#' - **Pathway B**: GTF + genome - Extract transcriptome from BSgenome
#' - **Pathway C**: GTF + FASTA + pre-built Kallisto index
#'
#' The index includes:
#' - Kallisto index for pseudoalignment
#' - P matrices mapping equivalence classes to transcripts
#' - Positional distance information for bias correction
#' - Covariate matrices for prior estimation
#' - Optional: GTF annotation and transcriptome sequences (for long-read workflows)
#'
#' @param annotation Path to GTF annotation file (required)
#' @param transcriptome Path to transcriptome FASTA file (optional if genome provided)
#' @param genome BSgenome object or package name for transcriptome extraction
#'   (e.g., "BSgenome.Hsapiens.UCSC.hg38"). Required if transcriptome not provided.
#' @param kallisto_index Path to pre-built Kallisto index (optional). If provided
#'   along with transcriptome, skips Kallisto index building.
#' @param output_file Output file path for bundled index. If ends in ".rds" or
#'   ".mpaqt.idx", creates a single bundled file. Otherwise creates directory
#'   with separate files (legacy behavior).
#' @param read_length Expected read length (default: 75)
#' @param stride Stride for read simulation (default: 1)
#' @param threads Number of threads for parallel operations (default: 1)
#' @param chunk_size Number of simulated reads per chunk (default: 10000000)
#' @param store_sequences Store transcriptome sequences in index for long-read
#'   workflows (default: FALSE)
#' @param store_gtf Store GTF annotation in index for long-read workflows
#'   (default: FALSE)
#' @param temp_dir Temporary directory for intermediate files
#' @param keep_temp Keep temporary files after completion (default: FALSE)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return An `mpaqt_index` object (invisibly)
#'
#' @details
#' ## Input Pathways
#'
#' **Pathway A (GTF + FASTA):** Standard workflow. Provide `annotation` and
#' `transcriptome`. A Kallisto index will be built from the FASTA file.
#'
#' **Pathway B (GTF + genome):** When you have a GTF but no transcriptome FASTA.
#' Provide `annotation` and `genome` (BSgenome package name or object).
#' Transcriptome sequences are extracted from the genome using GTF coordinates.
#'
#' **Pathway C (GTF + FASTA + pre-built index):** When you already have a
#' Kallisto index. Provide `annotation`, `transcriptome`, and `kallisto_index`.
#' Skips Kallisto index building but still needs the FASTA to build P matrices.
#'
#' ## Index Creation Process
#' 1. Obtains transcriptome sequences (from FASTA or genome extraction)
#' 2. Creates a Kallisto index (unless pre-built index provided)
#' 3. Parses GTF to extract gene-transcript mappings
#' 4. Simulates reads from each transcript position
#' 5. Runs kallisto bus to determine equivalence class memberships
#' 6. Builds P matrices with positional distance information
#' 7. Creates covariate matrix for prior modeling
#' 8. Bundles everything into a single portable file
#'
#' PolyA tails are appended to transcripts of appropriate biotypes to better
#' model 3' bias in poly(A)-selected libraries.
#'
#' @section Output:
#' By default, creates a single bundled file containing all index components
#' including the Kallisto index binary. This makes the index fully portable.
#'
#' For long-read workflows (FLNC FASTQ processing), set `store_sequences = TRUE`
#' and `store_gtf = TRUE` to include the reference data needed for minimap2
#' alignment and Bambu quantification. Both options default to `FALSE`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Pathway A: Build from transcriptome FASTA
#' idx <- mpaqt_index(
#'     annotation = "annotation.gtf",
#'     transcriptome = "transcriptome.fa",
#'     output_file = "my_index.mpaqt.idx"
#' )
#'
#' # Pathway B: Extract transcriptome from genome
#' idx <- mpaqt_index(
#'     annotation = "annotation.gtf",
#'     genome = "BSgenome.Hsapiens.UCSC.hg38",
#'     output_file = "my_index.mpaqt.idx"
#' )
#'
#' # Pathway C: Use pre-built Kallisto index
#' idx <- mpaqt_index(
#'     annotation = "annotation.gtf",
#'     transcriptome = "transcriptome.fa",
#'     kallisto_index = "existing.kallisto.idx",
#'     output_file = "my_index.mpaqt.idx"
#' )
#'
#' # View index summary
#' print(idx)
#' }
mpaqt_index <- function(
    annotation,
    transcriptome = NULL,
    genome = NULL,
    kallisto_index = NULL,
    output_file = "mpaqt.index.rds",
    read_length = 75L,
    stride = 1L,
    threads = 1L,
    chunk_size = 10000000L,
    store_sequences = FALSE,
    store_gtf = FALSE,
    temp_dir = tempdir(),
    keep_temp = FALSE,
    verbose = TRUE
) {
    # =========================================================================
    # Input Validation and Pathway Detection
    # =========================================================================
    validate_gtf(annotation)

    pathway <- detect_index_pathway(
        transcriptome = transcriptome,
        kallisto_index = kallisto_index,
        genome = genome
    )

    if (verbose) {
        cli::cli_h1("Creating MPAQT Index")
        cli::cli_alert_info("Input pathway: {.val {pathway}}")
    }

    # Determine if we're creating a bundled output
    is_bundled_output <- grepl("\\.(rds|idx)$", output_file, ignore.case = TRUE)

    if (is_bundled_output) {
        output_dir <- dirname(output_file)
        if (output_dir == ".") output_dir <- getwd()
    } else {
        # Legacy: output_file is actually a directory
        output_dir <- output_file
        output_file <- file.path(output_dir, "mpaqt.index.rds")
    }

    validate_output_dir(output_dir)

    # Temporary Kallisto index path
    kallisto_index_path <- file.path(temp_dir, "mpaqt.kallisto.idx")

    # =========================================================================
    # Pathway-Specific: Obtain Transcriptome and Kallisto Index
    # =========================================================================

    if (pathway == "genome") {
        # Pathway B: Extract transcriptome from genome
        if (verbose) cli::cli_progress_step("Extracting transcriptome from genome")

        fa_seqs <- extract_transcriptome_from_gtf(annotation, genome, verbose = verbose)

        # Write to temp FASTA for Kallisto
        temp_fasta <- file.path(temp_dir, "extracted_transcriptome.fa")
        require_bioc("Biostrings", "to write FASTA")
        Biostrings::writeXStringSet(fa_seqs, temp_fasta)
        transcriptome <- temp_fasta

        # Build Kallisto index
        if (verbose) cli::cli_progress_step("Creating kallisto index")
        require_bioc("Biostrings", "to read transcriptome FASTA")

        run_kallisto_index(
            transcriptome = transcriptome,
            index_file = kallisto_index_path,
            threads = threads,
            output_dir = temp_dir
        )

    } else if (pathway == "fasta") {
        # Pathway A: Build from FASTA
        validate_fasta(transcriptome)
        require_bioc("Biostrings", "to read transcriptome FASTA")

        if (verbose) cli::cli_progress_step("Creating kallisto index")

        run_kallisto_index(
            transcriptome = transcriptome,
            index_file = kallisto_index_path,
            threads = threads,
            output_dir = temp_dir
        )

        # Read sequences for later storage
        fa_seqs <- Biostrings::readDNAStringSet(transcriptome, format = "fasta")

    } else if (pathway == "prebuilt") {
        # Pathway C: Use pre-built Kallisto index
        validate_fasta(transcriptome)
        validate_kallisto_index(kallisto_index)
        require_bioc("Biostrings", "to read transcriptome FASTA")

        if (verbose) cli::cli_alert_info("Using pre-built Kallisto index")

        kallisto_index_path <- kallisto_index

        # Read sequences for later storage
        fa_seqs <- Biostrings::readDNAStringSet(transcriptome, format = "fasta")
    }

    require_bioc("rtracklayer", "to parse GTF annotation")

    # =========================================================================
    # Step 2: Parse GTF annotation
    # =========================================================================
    if (verbose) cli::cli_progress_step("Parsing GTF annotation")

    gtf <- rtracklayer::import(annotation)
    gtf <- data.table::as.data.table(gtf)

    # Filter to transcripts and extract required columns
    gtf <- gtf[type == "transcript"]

    # Handle missing transcript_type and gene_type columns gracefully
    if (!"transcript_type" %in% names(gtf)) {
        gtf[, transcript_type := "protein_coding"]  # Default assumption
    }
    if (!"gene_type" %in% names(gtf)) {
        gtf[, gene_type := "protein_coding"]  # Default assumption
    }

    gtf <- gtf[, .(
        tr_id = transcript_id,
        gene_id = gene_id,
        transcript_type = transcript_type,
        gene_type = gene_type
    )]

    # Store full GTF for long-read workflows (before filtering to transcripts only)
    gtf_full <- if (store_gtf) {
        data.table::as.data.table(rtracklayer::import(annotation))
    } else {
        NULL
    }

    # =========================================================================
    # Step 3: Process transcriptome and compute covariates
    # =========================================================================
    if (verbose) cli::cli_progress_step("Processing transcriptome sequences")

    # fa_seqs was already read/extracted above
    fa_dt <- data.table::data.table(
        tr_id = stringr::str_remove(names(fa_seqs), "[|].*"),
        tr_seq = as.character(fa_seqs)
    )
    fa_dt[, tr_len := nchar(tr_seq)]
    fa_dt[, gc_ratio := stringr::str_count(tr_seq, "[GC]") / tr_len]

    # Build covariate table
    cov_dt <- fa_dt[, .(tr_id, tr_len, gc_ratio)]
    cov_dt <- merge(
        cov_dt,
        gtf[, .(tr_id, transcript_type, gene_type)],
        by = "tr_id",
        all.x = TRUE
    )

    # Handle missing annotations
    cov_dt[is.na(gene_type), gene_type := "unknown"]
    cov_dt[, is_protein_coding := as.integer(gene_type == "protein_coding")]

    # =========================================================================
    # Step 4: Append polyA tails to appropriate transcripts
    # =========================================================================
    if (verbose) cli::cli_progress_step("Adding polyA tails to eligible transcripts")

    biotypes_polyA <- get_polya_biotypes()
    cov_dt[, has_polyA := transcript_type %in% biotypes_polyA]
    trs_polyA <- cov_dt[has_polyA == TRUE, tr_id]

    polyA_seq <- paste(rep("A", read_length - 32), collapse = "")
    fa_dt[tr_id %in% trs_polyA, tr_seq := paste0(tr_seq, polyA_seq)]
    fa_dt[, tr_len := nchar(tr_seq)]

    if (verbose) cli::cli_alert_info("{length(trs_polyA)} transcripts received polyA tails")

    # =========================================================================
    # Step 5: Simulate reads and build P matrices
    # =========================================================================
    if (verbose) cli::cli_progress_step("Simulating reads for P matrix construction")

    # Calculate read counts per transcript
    fa_dt[, num_reads := as.integer((tr_len - read_length + 1) / stride)]
    fa_dt <- fa_dt[num_reads >= read_length]
    fa_dt[, cumsum_reads := cumsum(num_reads)]

    total_reads <- sum(fa_dt$num_reads)
    if (verbose) cli::cli_alert_info("Total simulated reads: {format(total_reads, big.mark = ',')}")

    # Chunk transcripts for processing
    chunk_bounds <- seq(0, total_reads, by = chunk_size)
    fa_dt[, chunk := findInterval(cumsum_reads, chunk_bounds)]

    fa_chunks <- split(fa_dt, by = "chunk")
    n_chunks <- length(fa_chunks)
    if (verbose) cli::cli_alert_info("Processing in {n_chunks} chunk{?s}")

    # Process each chunk
    read_qual <- paste(rep("I", read_length), collapse = "")

    results <- purrr::imap(fa_chunks, function(chunk_dt, chunk_id) {
        process_index_chunk(
            chunk_dt = chunk_dt,
            chunk_id = chunk_id,
            kallisto_index = kallisto_index_path,
            read_length = read_length,
            stride = stride,
            read_qual = read_qual,
            threads = threads,
            temp_dir = temp_dir,
            verbose = verbose
        )
    })

    # =========================================================================
    # Step 6: Aggregate results across chunks
    # =========================================================================
    if (verbose) cli::cli_progress_step("Aggregating chunk results")

    counts_dt <- data.table::rbindlist(lapply(results, `[[`, "counts"))
    distances_dt <- data.table::rbindlist(lapply(results, `[[`, "distances"))

    # Aggregate counts
    counts_dt <- counts_dt[, .(N = sum(N)), by = .(ec_tr_id, tr_id)]

    # Aggregate distances (weighted average)
    distances_dt <- distances_dt[, .(
        total_count = sum(count),
        dist_5p = sum(sum_dist_5p) / sum(count),
        dist_3p = sum(sum_dist_3p) / sum(count)
    ), by = .(ec_tr_id, tr_id)]

    # =========================================================================
    # Step 7: Build sparse P matrix
    # =========================================================================
    if (verbose) cli::cli_progress_step("Building P matrix")

    ec_tr_ids <- unique(counts_dt$ec_tr_id)
    tr_ids <- unique(counts_dt$tr_id)

    counts_dt[, `:=`(
        ec_idx = match(ec_tr_id, ec_tr_ids),
        tr_idx = match(tr_id, tr_ids)
    )]

    p_mat <- Matrix::sparseMatrix(
        i = counts_dt$ec_idx,
        j = counts_dt$tr_idx,
        x = counts_dt$N,
        dims = c(length(ec_tr_ids), length(tr_ids)),
        dimnames = list(ec_tr_ids, tr_ids)
    )

    p_mat <- methods::as(p_mat, "CsparseMatrix")
    p_mat <- p_mat[, which(Matrix::colSums(p_mat) != 0)]

    # Extract final transcript and EC lists
    p_trs <- colnames(p_mat)
    p_n <- Matrix::rowSums(p_mat)
    p_ecs <- names(p_n)

    # =========================================================================
    # Step 8: Create P list with embedded distance information
    # =========================================================================
    if (verbose) cli::cli_progress_step("Embedding distance information in P matrices")

    p_list <- build_p_list_with_distances(p_mat, p_trs, p_ecs, distances_dt)
    names(p_list) <- p_trs

    # =========================================================================
    # Step 9: Finalize covariate matrix
    # =========================================================================
    if (verbose) cli::cli_progress_step("Finalizing covariate matrix")

    cov_dt <- cov_dt[tr_id %in% p_trs]
    cov_dt <- cov_dt[match(p_trs, cov_dt$tr_id)]
    stopifnot(identical(cov_dt$tr_id, p_trs))

    cov_mat <- stats::model.matrix(
        ~ log(gc_ratio) + log(tr_len) + is_protein_coding,
        data = cov_dt
    )

    # =========================================================================
    # Step 10: Build transcript-to-gene mappings
    # =========================================================================
    if (verbose) cli::cli_progress_step("Building transcript-gene mappings")

    t2g_dt <- gtf[, .(tr_id, gene_id)]
    t2g_dt <- t2g_dt[tr_id %in% p_trs]
    t2g_dt <- t2g_dt[match(p_trs, t2g_dt$tr_id)]
    stopifnot(identical(t2g_dt$tr_id, p_trs))

    p_genes <- t2g_dt$gene_id
    p_genes_uniq <- unique(p_genes)

    t2g_dt[, `:=`(
        tr_idx = match(tr_id, p_trs),
        gene_idx = match(gene_id, p_genes_uniq)
    )]

    t2g_mat <- Matrix::sparseMatrix(
        i = t2g_dt$tr_idx,
        j = t2g_dt$gene_idx,
        x = 1,
        dimnames = list(p_trs, p_genes_uniq)
    )

    t2g_mat <- methods::as(t2g_mat, "CsparseMatrix")
    g2t_mat <- Matrix::t(t2g_mat)

    # Normalized version for averaging
    t2g_mat_norm <- t2g_mat
    t2g_mat_norm@x <- t2g_mat_norm@x / rep.int(
        Matrix::colSums(t2g_mat_norm),
        diff(t2g_mat_norm@p)
    )

    # =========================================================================
    # Step 11: Create and bundle index object
    # =========================================================================
    if (verbose) cli::cli_progress_step("Creating index object")

    # Distance matrix for the index
    dist_mat <- distances_dt[
        ec_tr_id %in% p_ecs & tr_id %in% p_trs,
        .(ec_tr_id, tr_id, dist_5p, dist_3p)
    ]

    # Prepare transcriptome sequences for storage
    transcriptome_for_storage <- if (store_sequences) {
        # Filter to transcripts in index and convert to named character
        seqs_in_index <- fa_seqs[names(fa_seqs) %in% p_trs |
                                   stringr::str_remove(names(fa_seqs), "[|].*") %in% p_trs]
        stats::setNames(as.character(seqs_in_index), names(seqs_in_index))
    } else {
        NULL
    }

    index <- new_mpaqt_index(
        transcripts = p_trs,
        genes = p_genes,
        ec_ids = p_ecs,
        p_matrices = p_list,
        ec_counts = p_n,
        covariates = cov_mat,
        distances = dist_mat,
        t2g_matrix = t2g_mat,
        g2t_matrix = g2t_mat,
        t2g_normalized = t2g_mat_norm,
        kallisto_index = kallisto_index_path,
        gtf_annotation = gtf_full,
        transcriptome_seqs = transcriptome_for_storage
    )

    # Bundle and save
    if (verbose) cli::cli_progress_step("Bundling and saving index")

    bundle_mpaqt_index(
        index = index,
        kallisto_index_path = kallisto_index_path,
        gtf_annotation = gtf_full,
        transcriptome_seqs = transcriptome_for_storage,
        output_file = output_file,
        compress = "xz",
        verbose = verbose
    )

    # =========================================================================
    # Cleanup
    # =========================================================================
    if (!keep_temp) {
        chunk_dirs <- file.path(temp_dir, paste0("mpaqt_chunk_", seq_along(fa_chunks)))
        unlink(chunk_dirs, recursive = TRUE)
        # Also clean up temp kallisto index if we built it
        if (pathway != "prebuilt" && file.exists(kallisto_index_path)) {
            unlink(kallisto_index_path)
        }
    }

    if (verbose) {
        cli::cli_progress_done()

        cli::cli_h2("Index Summary")
        cli::cli_alert_success("Transcripts: {.val {length(p_trs)}}")
        cli::cli_alert_success("Genes: {.val {length(p_genes_uniq)}}")
        cli::cli_alert_success("Equivalence classes: {.val {length(p_ecs)}}")
        cli::cli_alert_success("P matrix entries: {.val {nrow(counts_dt)}}")
        cli::cli_text("")
        cli::cli_alert_info("5' distance range: [{round(min(dist_mat$dist_5p), 1)}, {round(max(dist_mat$dist_5p), 1)}]")
        cli::cli_alert_info("3' distance range: [{round(min(dist_mat$dist_3p), 1)}, {round(max(dist_mat$dist_3p), 1)}]")
        cli::cli_text("")
        cli::cli_alert_info("Input pathway: {.val {pathway}}")
        cli::cli_alert_info("Stored sequences: {.val {store_sequences}}")
        cli::cli_alert_info("Stored GTF: {.val {store_gtf}}")
        cli::cli_text("")
        cli::cli_alert_success("Bundled index saved: {.path {output_file}}")
    }

    # Return the bundled index (read back to include kallisto binary)
    invisible(readRDS(output_file))
}

# =============================================================================
# Helper functions
# =============================================================================

#' Get biotypes that have polyA tails
#'
#' @return Character vector of transcript biotypes
#' @keywords internal
get_polya_biotypes <- function() {
    c(
        "unitary_pseudogene",
        "unprocessed_pseudogene",
        "IG_C_gene",
        "IG_C_pseudogene",
        "IG_D_gene",
        "IG_J_gene",
        "IG_J_pseudogene",
        "IG_pseudogene",
        "IG_V_gene",
        "IG_V_pseudogene",
        "lncRNA",
        "non_stop_decay",
        "nonsense_mediated_decay",
        "processed_pseudogene",
        "processed_transcript",
        "protein_coding",
        "protein_coding_CDS_not_defined",
        "protein_coding_LoF",
        "retained_intron",
        "TEC",
        "TR_C_gene",
        "TR_D_gene",
        "TR_J_gene",
        "TR_J_pseudogene",
        "TR_V_gene",
        "TR_V_pseudogene",
        "transcribed_processed_pseudogene",
        "transcribed_unitary_pseudogene",
        "transcribed_unprocessed_pseudogene",
        "translated_processed_pseudogene"
    )
}

#' Process a single chunk for index building
#'
#' @param chunk_dt data.table with transcript sequences for this chunk
#' @param chunk_id Chunk identifier
#' @param kallisto_index Path to kallisto index
#' @param read_length Read length
#' @param stride Stride for read simulation
#' @param read_qual Quality string for simulated reads
#' @param threads Number of threads
#' @param temp_dir Temporary directory
#' @param verbose Print progress messages
#'
#' @return List with counts and distances data.tables
#' @keywords internal
process_index_chunk <- function(
    chunk_dt,
    chunk_id,
    kallisto_index,
    read_length,
    stride,
    read_qual,
    threads,
    temp_dir,
    verbose = TRUE
) {
    if (verbose) cli::cli_alert("Processing chunk {chunk_id}")

    # Create chunk-specific directory
    chunk_dir <- file.path(temp_dir, paste0("mpaqt_chunk_", chunk_id))
    dir.create(chunk_dir, showWarnings = FALSE, recursive = TRUE)
    fastq_file <- file.path(chunk_dir, "reads.fastq.gz")

    # Calculate read positions
    starts <- purrr::map(chunk_dt$tr_len, ~ seq(1, .x - read_length + 1, by = stride))
    ends <- purrr::map(starts, ~ .x + read_length - 1)

    # Calculate read IDs (0-based for kallisto)
    chunk_dt[, cumsum_reads := cumsum(num_reads)]
    # chunk_dt[, read_id_start := c(0, cumsum_reads[1:(.N - 1)])]
    chunk_dt[, read_id_start := c(0, cumsum_reads[seq_len(.N - 1L)])]
    chunk_dt[, read_id_end := cumsum_reads - 1]

    read_ids <- purrr::pmap(
        chunk_dt[, .(read_id_start, read_id_end)],
        ~ seq(.x, .y)
    )

    # Build read info table
    read_info_dt <- data.table::rbindlist(purrr::pmap(
        list(
            tr_id = chunk_dt$tr_id,
            tr_len = chunk_dt$tr_len,
            start = starts,
            end = ends,
            read_id = read_ids
        ),
        function(tr_id, tr_len, start, end, read_id) {
            data.table::data.table(
                tr_id = tr_id,
                tr_len = tr_len,
                start = start,
                end = end,
                read_id = read_id
            )
        }
    ))

    # Calculate distances
    read_info_dt[, `:=`(
        dist_5p = start - 1,
        dist_3p = tr_len - end
    )]

    # Extract read sequences
    chunk_seqs <- unlist(purrr::pmap(
        list(
            string = chunk_dt$tr_seq,
            start = starts,
            end = ends
        ),
        stringr::str_sub
    ))

    # Create FASTQ file
    fastq_dt <- data.table::data.table(
        fa_id = paste0("@", read_info_dt$read_id, "|", read_info_dt$tr_id, "|", read_info_dt$start),
        read_seq = chunk_seqs,
        plus = "+",
        qual = read_qual
    )

    data.table::fwrite(
        fastq_dt,
        file = fastq_file,
        sep = "\n",
        quote = FALSE,
        row.names = FALSE,
        col.names = FALSE,
        nThread = threads
    )

    # Run kallisto bus
    run_kallisto_bus(
        index_file = kallisto_index,
        fastq_files = fastq_file,
        output_dir = chunk_dir,
        threads = threads,
        technology = "bulk"
    )

    # Convert bus to text
    bus_file <- file.path(chunk_dir, "output.bus")
    bus_txt_file <- file.path(chunk_dir, "output.bus.txt")
    run_bustools_text(bus_file, bus_txt_file, output_dir = chunk_dir)

    # Read results
    ec_file <- file.path(chunk_dir, "matrix.ec")

    bus_dt <- read_bus_text(bus_txt_file, columns = c(3, 5))
    ec_dt <- read_ec_mapping(ec_file)

    # Join to get EC assignments with distances
    ec_with_dist <- bus_dt[read_info_dt, on = "read_id"][ec_dt, on = "ec_id"]

    # Aggregate counts
    counts_dt <- ec_with_dist[, .N, by = .(ec_tr_id, tr_id)]

    # Aggregate distances
    distances_dt <- ec_with_dist[, .(
        count = .N,
        sum_dist_5p = sum(dist_5p),
        sum_dist_3p = sum(dist_3p)
    ), by = .(ec_tr_id, tr_id)]

    list(counts = counts_dt, distances = distances_dt)
}

#' Build P list with embedded distance information
#'
#' @param p_mat Sparse P matrix
#' @param p_trs Transcript IDs (column names)
#' @param p_ecs EC IDs (row names)
#' @param distances_dt Distance information data.table
#'
#' @return List of data.tables, one per transcript
#' @keywords internal
build_p_list_with_distances <- function(p_mat, p_trs, p_ecs, distances_dt) {
    # Use a keyed copy for O(log n) lookups — do NOT modify the original
    # distances_dt in-place, as setkey would re-sort it and break the
    # simulation natural order that index$distances must preserve
    distances_dt <- data.table::copy(distances_dt)
    data.table::setkey(distances_dt, tr_id, ec_tr_id)

    lapply(seq_len(ncol(p_mat)), function(j) {
        idx_start <- p_mat@p[j] + 1
        idx_end <- p_mat@p[j + 1]

        if (idx_start <= idx_end) {
            ec_indices <- p_mat@i[idx_start:idx_end] + 1
            values <- p_mat@x[idx_start:idx_end]
            ec_names <- p_ecs[ec_indices]
            tr_name <- p_trs[j]

            # Fast keyed lookup
            dist_subset <- distances_dt[.(tr_name, ec_names), nomatch = NULL]
            dist_subset <- dist_subset[match(ec_names, dist_subset$ec_tr_id)]

            data.table::data.table(
                i = ec_indices,
                x = values,
                dist_5p = dist_subset$dist_5p,
                dist_3p = dist_subset$dist_3p
            )
        } else {
            data.table::data.table(
                i = integer(0),
                x = numeric(0),
                dist_5p = numeric(0),
                dist_3p = numeric(0)
            )
        }
    })
}

#' Load MPAQT Index from Disk
#'
#' Read a previously created MPAQT index from an RDS file.
#'
#' @param path Path to the index RDS file
#'
#' @return An `mpaqt_index` object
#'
#' @export
#'
#' @examples
#' \dontrun{
#' idx <- mpaqt_read_index("my_index/mpaqt.index.rds")
#' print(idx)
#' }
mpaqt_read_index <- function(path) {
    validate_file_exists(path, "Index file")

    index <- readRDS(path)

    # Handle legacy format
    if (!inherits(index, "mpaqt_index")) {
        if (all(c("I", "G", "E", "P") %in% names(index))) {
            cli::cli_alert_info("Converting legacy index format")
            index <- convert_legacy_index(index)
        } else {
            cli::cli_abort(c(
                "Invalid index file: {.path {path}}",
                "i" = "File does not contain a valid MPAQT index"
            ))
        }
    }

    index
}

#' Convert legacy index format
#'
#' @param legacy_index List in legacy format
#'
#' @return An mpaqt_index object
#' @keywords internal
convert_legacy_index <- function(legacy_index) {
    new_mpaqt_index(
        transcripts = legacy_index$I,
        genes = legacy_index$G,
        ec_ids = legacy_index$E,
        p_matrices = legacy_index$P,
        ec_counts = legacy_index$N,
        covariates = legacy_index$C,
        distances = legacy_index$D,
        t2g_matrix = legacy_index$T2G,
        g2t_matrix = legacy_index$G2T,
        t2g_normalized = legacy_index$T2Gn,
        kallisto_index = NULL
    )
}

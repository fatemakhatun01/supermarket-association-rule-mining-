# Project 2 Milestone 1
# Fatema Khatun

# Install missing packages
packages <- c("arules", "arulesViz")

missing_packages <- setdiff(
  packages,
  rownames(installed.packages())
)

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}

# Load packages
library(arules)
library(arulesViz)


# Read the supermarket dataset
df <- read.table(
  "Supermarket (1).csv",
  sep = ",",
  header = TRUE,
  stringsAsFactors = FALSE
)

# Check dimensions and recorded values
dim(df)
table(unlist(df), useNA = "ifany")

# Convert purchases to TRUE and non-purchases to FALSE
mat <- df == "t"

# Convert to transactions
trans <- as(mat, "transactions")

# Inspect the transaction dataset
trans
summary(trans)


# Requirement 1(a): Frequent itemsets
frequent_itemsets <- apriori(
  trans,
  parameter = list(
    target = "frequent itemsets",
    support = 0.25,
    minlen = 1
  )
)

# Sort by support, highest first
frequent_itemsets <- sort(
  frequent_itemsets,
  by = "support",
  decreasing = TRUE
)

# Display the total number of frequent itemsets
length(frequent_itemsets)

# Display the top 10
inspect(head(frequent_itemsets, n = 10))





# Requirement 1(b): Maximal frequent itemsets
maximal_itemsets <- apriori(
  trans,
  parameter = list(
    target = "maximally frequent itemsets",
    support = 0.25,
    minlen = 1
  )
)

# Sort by support, highest first
maximal_itemsets <- sort(
  maximal_itemsets,
  by = "support",
  decreasing = TRUE
)

# Display the total number
length(maximal_itemsets)

# Display the top 10
inspect(head(maximal_itemsets, n = 10))



# Requirement 1(c): Compression ratio
n_frequent <- length(frequent_itemsets)
n_maximal <- length(maximal_itemsets)

compression_ratio <- n_frequent / n_maximal
reduction_percent <- (1 - n_maximal / n_frequent) * 100

cat("Frequent itemsets:", n_frequent, "\n")
cat("Maximal frequent itemsets:", n_maximal, "\n")
cat("Compression ratio:",
    round(compression_ratio, 4), "to 1\n")
cat("Reduction in itemset count:",
    round(reduction_percent, 2), "%\n")


# Requirement 1(d): Rules ranked by confidence
rules <- apriori(
  trans,
  parameter = list(
    target = "rules",
    support = 0.25,
    confidence = 0.80,
    minlen = 2
  )
)

# Display the total number of generated rules
length(rules)

# Select the top 20 rules by confidence
top20_confidence <- head(
  sort(rules, by = "confidence", decreasing = TRUE),
  n = 20
)

# Display the results
inspect(top20_confidence)



# Requirement 1(e): Top 20 rules ranked by lift
top20_lift <- head(
  sort(rules, by = "lift", decreasing = TRUE),
  n = 20
)

# Display the results
inspect(top20_lift)


# Requirement 1(f): Compare consequent diversity
table(labels(rhs(top20_confidence)))
table(labels(rhs(top20_lift)))

# Number of distinct consequents
length(unique(labels(rhs(top20_confidence))))
length(unique(labels(rhs(top20_lift))))


# Requirement 2(a): Check all 52 generated rules
redundant_flags <- is.redundant(rules)

# Summarize the results
cat("Total rules:", length(rules), "\n")
cat("Redundant rules:", sum(redundant_flags), "\n")
cat("Non-redundant rules:", sum(!redundant_flags), "\n")

# Display redundant rules, if any
if (any(redundant_flags)) {
  inspect(rules[redundant_flags])
} else {
  cat("No redundant rules were found.\n")
}

# Keep non-redundant rules for later use
rules_nonredundant <- rules[!redundant_flags]



# Requirement 3(a): Graph of the verified rules

# Install igraph if needed
if (!requireNamespace("igraph", quietly = TRUE)) {
  install.packages("igraph")
}

# Create one directed edge for each rule
rule_edges <- data.frame(
  from = labels(lhs(rules_nonredundant)),
  to = labels(rhs(rules_nonredundant)),
  support = quality(rules_nonredundant)$support,
  confidence = quality(rules_nonredundant)$confidence,
  lift = quality(rules_nonredundant)$lift
)

# Create the graph
rule_graph <- igraph::graph_from_data_frame(
  rule_edges,
  directed = TRUE
)

# Wrap itemset labels for readability
node_labels <- gsub(
  ", ",
  ",\n",
  igraph::V(rule_graph)$name,
  fixed = TRUE
)

# Highlight nodes that receive rule arrows
node_colors <- ifelse(
  igraph::degree(rule_graph, mode = "in") > 0,
  "orange",
  "lightblue"
)

# Fix the layout for reproducibility
set.seed(11816730)
graph_layout <- igraph::layout_with_fr(rule_graph)

# Draw the graph
plot(
  rule_graph,
  layout = graph_layout,
  vertex.label = node_labels,
  vertex.color = node_colors,
  vertex.size = 7,
  vertex.label.cex = 0.6,
  vertex.label.color = "black",
  edge.color = "gray60",
  edge.arrow.size = 0.35,
  main = "Association Rules After Redundancy Checking",
  margin = 0.15
)

# Show how many rules predict each consequent
table(labels(rhs(rules_nonredundant)))




# Requirement 3(a): Readable graph pages
# Uses the rule_edges table already created

page_groups <- split(
  seq_len(nrow(rule_edges)),
  ceiling(seq_len(nrow(rule_edges)) / 18)
)

for (p in seq_along(page_groups)) {
  
  page_edges <- rule_edges[page_groups[[p]], ]
  
  g <- igraph::graph_from_data_frame(
    page_edges,
    directed = TRUE
  )
  
  node_names <- igraph::V(g)$name
  is_consequent <- node_names %in% page_edges$to
  
  # Place antecedents on the left, consequents on the right
  positions <- matrix(0, nrow = length(node_names), ncol = 2)
  positions[, 1] <- ifelse(is_consequent, 1, -1)
  
  for (side in c(FALSE, TRUE)) {
    ids <- which(is_consequent == side)
    
    if (length(ids) > 0) {
      positions[ids, 2] <- if (length(ids) == 1) {
        0
      } else {
        seq(1, -1, length.out = length(ids))
      }
    }
  }
  
  # Wrap long labels
  readable_labels <- vapply(
    node_names,
    function(x) paste(strwrap(x, width = 38), collapse = "\n"),
    character(1)
  )
  
  # Save a clear image in your project folder
  png(
    filename = paste0("Requirement3_Graph_Page", p, ".png"),
    width = 2400,
    height = 3000,
    res = 200
  )
  
  par(mar = c(2, 2, 4, 2))
  
  plot(
    g,
    layout = positions,
    vertex.label = readable_labels,
    vertex.color = ifelse(is_consequent, "orange", "lightblue"),
    vertex.size = 5,
    vertex.label.cex = 0.75,
    vertex.label.color = "black",
    vertex.label.dist = 0.5,
    vertex.label.degree = ifelse(is_consequent, 0, pi),
    edge.color = "gray60",
    edge.arrow.size = 0.4,
    xlim = c(-2.4, 2.4),
    ylim = c(-1.15, 1.15),
    rescale = FALSE,
    asp = 0,
    main = paste("Association Rules - Page", p)
  )
  
  dev.off()
}







# Requirement 4: Select three absent consequent itemsets

# Show the consequents in the top 20 lift-ranked rules
existing_consequents <- unique(labels(rhs(top20_lift)))
print(existing_consequents)

# Calculate support for every individual item
item_support <- itemFrequency(trans, type = "relative")

# Create a table of singleton itemsets and their frequencies
item_evidence <- data.frame(
  itemset = paste0("{", names(item_support), "}"),
  support = as.numeric(item_support),
  count = as.integer(round(
    as.numeric(item_support) * length(trans)
  ))
)

# Keep itemsets absent from the existing consequents
absent_candidates <- item_evidence[
  !(item_evidence$itemset %in% existing_consequents),
]

# Rank candidates by support, highest first
absent_candidates <- absent_candidates[
  order(absent_candidates$support, decreasing = TRUE),
]

# Select the three most frequent absent itemsets
selected_itemsets <- head(absent_candidates, 3)

# Confirm that they are absent from the consequents
selected_itemsets$appears_in_top20_rhs <-
  selected_itemsets$itemset %in% existing_consequents

print(selected_itemsets, row.names = FALSE)
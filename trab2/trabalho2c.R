library(igraph)
library(conflicted)
library(magrittr)
library(icecream)
library(restorepoint)
library(tibble)
library(ggplot2)


#### Questão 1 ####

## Clique com 10 nodos

set.seed(1)
graph.full(10, directed = F) -> g
set.seed(1)
g |> plot()

get_neighbors <- function(graph, node) {
  # dps n da pra faer vetor deles se n fizer isto
  neighbors(graph, node) %>% as.integer()
}

# 0 <= p <= 1
# 1 <= n_ligacoes

# Função para fazer uma iteração do modelo de Random Walk
random_walk_model_iter <- function(graph, p = 0.8, n_ligacoes = 3,debug_ = F, i = FALSE) {
  if(debug_) {
    ic_enable()
  } else {
    ic_disable()
  }
  if (isFALSE(i)) {
    restore.point(paste0("iter_",i), to.global = TRUE)
  }
  graph %<>% add_vertices(1)
  # vars
  nodo_ligado      <- sample(1:(vcount(graph) - 1), 1)
  ic(nodo_ligado)
  nodo_novo        <- vcount(graph)
  ic(nodo_novo)
  
  
  neighbors_de_ligado <- get_neighbors(graph, nodo_ligado)
  ic(neighbors_de_ligado)
  graph %<>% add_edges(c(nodo_novo, nodo_ligado))
  
  # dps de ter o primeiro link, comecar o loop
  for (i in 2:n_ligacoes) {
    ic(i)
    # escolher um vizinho do nodo ligado (ainda não escolhido)
    nodo_para_aceitar <- setdiff(neighbors_de_ligado, get_neighbors(graph, nodo_novo)) %>% sample(1)
    ic(nodo_para_aceitar)
    u <- ic(runif(1))
    if(ic(u < p)) { # aceitar o vizinho
      graph %<>% add_edges(c(nodo_para_aceitar %>% as.integer(), nodo_novo))
    } else { # escolher outro sem ser o vizinho escolhido (ver nota)
      nodo_para_ligar <- 1:vcount(graph) %>%  
        # todos excepto o rejeitado, os já ligados e o próprio nodo novo
        setdiff(c(nodo_para_aceitar, get_neighbors(graph, nodo_novo), nodo_novo)) %>% 
        sample(1)
      graph %<>% add_edges(c(nodo_para_ligar, nodo_novo))
    }
  }
  graph
}
set.seed(1)
g %>% random_walk_model_iter(debug_ = T) %>%  plot()

# Função para fazer o modelo de Random Walk para uma rede com 200 nodos
random_walk_model <- function(g, nodes_wanted = 200, p = 0.8, n_ligacoes = 3, debug_ = F, seed = 1) {
  set.seed(seed)
  for (i in 1:(nodes_wanted - vcount(g))) {
    g %<>% random_walk_model_iter(p = p, n_ligacoes = n_ligacoes, i = ifelse(debug_, i, FALSE))
  }
  g
}

random_walk_model_w_stats <- function(g, nodes_wanted = 200, p = 0.8, n_ligacoes = 3, debug_ = F, seed = 1) {
  set.seed(seed)
  metricas <- tribble(~iter, ~distancias,  ~coef_clustering, ~triangulos)
  for (i in 1:(nodes_wanted - vcount(g))) {
    g %<>% random_walk_model_iter(p = p, n_ligacoes = n_ligacoes, i = ifelse(debug_, i, FALSE))
    metricas %<>% add_row(tibble(
      iter = i, 
      distancias = mean_distance(g), 
      coef_clustering = transitivity(g, type = "global"),
      triangulos = sum(count_triangles(g))
    ))
  }
  
  list(graph = g, metricas = metricas)
}


tab <- random_walk_model_w_stats(g, 200, 0.8, 3, T, 1)
tab

ggplot(tab$metricas, aes(x = iter, y = distancias)) + geom_point() + ylim(1, 3.5)
ggsave("distancias_rede_clique_inicial_10_nodos.svg")

ggplot(tab$metricas, aes(x = iter, y = coef_clustering)) + geom_point() + ylim(0.2,1)
ggsave("coef_clustering_rede_clique_inicial_10_nodos.svg")

ggplot(tab$metricas, aes(x = iter, y = triangulos)) + geom_point()
ggsave("triangulos_rede_clique_inicial_10_nodos.svg")

g_dps <- g %>% random_walk_model()
ic_enable()
ic(vcount(g_dps) == 200)
ic(is.simple(g_dps))
ic(ecount(g_dps) == (200-vcount(g))*3 + ecount(g))
g_dps %>% plot(vertex.size = 7, vertex.label.cex = 0.35)




# o que esta em cima mas funcao
# Gerar o número de redes desejado (how_many) com determinado nº nodos (nodes_wanted - 200)
make_graphs <- function(initial_g, how_many, nodes_wanted = 200, p = 0.8, n_ligacoes = 3, debug_ = FALSE, seed = 1) {
  set.seed(seed)
  graphs <- list()
  avg_distances <- numeric(how_many)  # Armazena as distâncias médias
  
  for (i in 1:how_many) {
    g_dps <- initial_g
    distances <- numeric(nodes_wanted - vcount(initial_g))
    
    for (j in 1:(nodes_wanted - vcount(initial_g))) {
      g_dps %<>% random_walk_model_iter(p = p, n_ligacoes = n_ligacoes, i = ifelse(debug_, j, FALSE))

    }
    

    graphs[[i]] <- g_dps
  }
  
  # Plotar a evolução da distância média
  
  graphs
}
make_graphs(g, 10) -> graphs
graphs[[7]] %>% plot(vertex.size = 7, vertex.label.cex = 0.35)

(dist_graus_rede_7 <- table(degree(graphs[[7]])))

(degree_df <- data.frame(table(degree(graphs[[7]]))))
colnames(degree_df) <- c("Grau", "Frequência")
degree_df

ggplot(degree_df, aes(x = factor(Grau), y = Frequência)) +
  geom_bar(stat = "identity", fill = "orange") +
  geom_text(aes(label = Frequência), vjust = -0.5, size = 3) +
  labs(x = "Grau", y = "Frequencia", title = "Distribuição de Grau na Rede") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))
ggsave("distribuicao_grau_rede_7_clique_10_nodos.svg")



# calcular as métricas
calculate_metrics <- function(graph) {
  mean_distance <- mean_distance(graph, directed = FALSE, unconnected = TRUE)
  clustering_coef <- transitivity(graph, type = "global")
  clustering_medio_coef <- mean(transitivity(graph, type = "local"))
  deg <- degree(graph, mode = "all")
  ht <- mean(deg^2)/mean(deg)^2
  
  tibble(
    Mean_Distance = mean_distance,
    Clustering_Coefficient = clustering_coef,
    Avg_Clustering_Coefficient = clustering_medio_coef,
    Heterogeneity = ht
  )
}
calculate_metrics_graphs <- function(graphs) {
  lapply(graphs, calculate_metrics) -> results
  tibble(
    Rede = 1:length(graphs),
    Distancia_Media = sapply(results, \(x) x$Mean_Distance),
    Coeficiente_de_Clustering = sapply(results, \(x) x$Clustering_Coefficient),
    Coeficiente_de_Clustering_Medio = sapply(results, \(x) x$Avg_Clustering_Coefficient),
    Heterogeneidade = sapply(results, \(x) x$Heterogeneity)
  )
}

(res_clique_inicial_10_nodos <- calculate_metrics_graphs(graphs))

mean(res_clique_inicial_10_nodos$Distancia_Media)
sd(res_clique_inicial_10_nodos$Distancia_Media)

mean(res_clique_inicial_10_nodos$Coeficiente_de_Clustering)
sd(res_clique_inicial_10_nodos$Coeficiente_de_Clustering)

## Clique com 20 nodos


set.seed(1)
graph.full(20, directed = F) -> g2
set.seed(1)
g2 %>% plot()

make_graphs(g2, 10, seed = 1) -> graphs2
graphs2[[7]] %>% plot(vertex.size = 7, vertex.label.cex = 0.35)

ggsave("rede_clique_inicial_20_nodos.svg")

(dist_graus_rede_7 <- table(degree(graphs2[[7]])))

(degree_df <- data.frame(table(degree(graphs2[[7]]))))
colnames(degree_df) <- c("Grau", "Frequência")
degree_df

ggplot(degree_df, aes(x = factor(Grau), y = Frequência)) +
  geom_bar(stat = "identity", fill = "orange") +
  geom_text(aes(label = Frequência), vjust = -0.5, size = 3) +
  labs(x = "Grau", y = "Frequencia", title = "Distribuição de Grau na Rede") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))
ggsave("distribuicao_grau_rede_7_clique_20_nodos.svg")


(res_clique_inicial_20_nodos <- calculate_metrics_graphs(graphs2))
mean(res_clique_inicial_20_nodos$Distancia_Media)
sd(res_clique_inicial_20_nodos$Distancia_Media)

mean(res_clique_inicial_20_nodos$Coeficiente_de_Clustering)
sd(res_clique_inicial_20_nodos$Coeficiente_de_Clustering)


tab2 <- random_walk_model_w_stats(g2, 200, 0.8, 3, T, 1)
tab2

ggplot(tab2$metricas, aes(x = iter, y = distancias)) + geom_point() + ylim(1, 3.5)
ggsave("distancias_rede_clique_inicial_20_nodos.svg")

ggplot(tab2$metricas, aes(x = iter, y = coef_clustering)) + geom_point() + ylim(0.2,1)
ggsave("coef_clustering_rede_clique_inicial_20_nodos.svg")

ggplot(tab2$metricas, aes(x = iter, y = triangulos)) + geom_point()
ggsave("triangulos_rede_clique_inicial_20_nodos.svg")



#### Questão 2 ####

# leitura da rede
rede <- read_graph("trab_links.txt", format = c("edgelist"), directed=F) # com estes args para reduzir tamanho do grafo

# representação visual da rede
plot(rede, vertex.size = 7, vertex.label.cex = .35)

# filtragem da componente gigante
componentes <- components(rede)
maior_componente <- which.max(componentes$csize)
(componente_gigante <- induced.subgraph(rede, which(componentes$membership == maior_componente)))
plot(componente_gigante, vertex.size = 7, vertex.label.cex = .35)


vcount(componente_gigante)
ecount(componente_gigante)


# grau medio


## Identificação de comunidades através da remoção de pontes

crm <- cluster_edge_betweenness(componente_gigante)
plot(crm, componente_gigante, vertex.size = 7, vertex.label.cex = .35)


# numero de comunidades
length(crm)

# tamanho das comunidades
sizes(crm)

print(paste("Comunidade de tamanho mínimo:", min(sizes(crm))))
print(paste("Comunidade de tamanho máximo:", max(sizes(crm))))

# tabela com a frequência de cada tamanho de comunidade
table(sizes(crm))

membership(crm)

# modularidade
modularity(crm)

## Identificação de comunidades através da propagação de etiquetas

set.seed(777)
cpe <- cluster_label_prop(componente_gigante)
plot(cpe, componente_gigante, vertex.size = 7, vertex.label.cex = .35)


# numero de comunidades
length(cpe)

# tamanho das comunidades
sizes(cpe)

print(paste("Comunidade de tamanho mínimo:", min(sizes(cpe))))
print(paste("Comunidade de tamanho máximo:", max(sizes(cpe))))

table(sizes(cpe))

membership(cpe)

# modularidade
modularity(cpe)


## Identificação de comunidades através da otimização da modularidade
## (método Fast Greedy)
com <- cluster_fast_greedy(componente_gigante)
plot(com, componente_gigante, vertex.size = 7, vertex.label.cex = .35)


# numero de comunidades
length(com)

# tamanho das comunidades
sizes(com)

print(paste("Comunidade de tamanho mínimo:", min(sizes(com))))
print(paste("Comunidade de tamanho máximo:", max(sizes(com))))

table(sizes(com))

membership(com)

# modularidade
modularity(com)


## Identificação de comunidades através de otimização da modularidade
## (método Louvain)

set.seed(777)
cl <- cluster_louvain(componente_gigante)
plot(cl, componente_gigante, vertex.size = 7, vertex.label.cex = .35)

# numero de comunidades
length(cl)

# tamanho das comunidades
sizes(cl)

print(paste("Comunidade de tamanho mínimo:", min(sizes(cl))))
print(paste("Comunidade de tamanho máximo:", max(sizes(cl))))

table(sizes(cl))

membership(cl)

# modularidade
modularity(cl)


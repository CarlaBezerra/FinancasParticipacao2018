
# Script para extrair dados do BD para a an�lise das finan�as municipais
# e do probabilidade de sobreviv�ncia do Or�amento Participativo.

# Criado por Murilo Junqueira

# Data cria��o: 2018-03-15
# Ultima modifica��o: 2018-05-04

################## Prepara �rea de trabalho ##################

#clean memory
rm(list=ls(all=TRUE))
gc()


# Os diret�rios de inser��o dos dados Brutos (InputFolder), destino dos 
# dados (OutputFolder) e localiza��o dos scripts (ScriptFolder). Atualize se necess�rio!
InputFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/BD csv/"
ScriptFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Scripts R/"
SpadaFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados Brutos/PBCENSUS Spada/"



# instala o pacote de extra��o dos dados, se necess�rio
library(tidyverse)
library(data.table)
library(readstata13)
library(readxl)
library(scales)



################## Carrega Dados ##################

# Dados de an�lise Spada
Spada.Data <- read.dta13(paste0(SpadaFolder, "PBCENSUS1989_2012data.dta"))

# Dados do censo do OP
Censo.OP <- read_excel(paste0(SpadaFolder, "05112017_PB CENSUS 2016.xlsx"), 
                                  sheet = "Final census") %>% filter(!is.na(codeipea))

# Dados Socioecon�micos
SocioDemoEconomia <- fread(paste0(InputFolder, "SocioDemoEconomia.csv"), 
                           sep = ";", dec = ",",
                           stringsAsFactors = FALSE)



################## Checa os dados de Spada ##################

# No me das vari�veis
names(Spada.Data)


# S� existe dados de 2004 a 2012.
table(Spada.Data$year)

# S� existe dados eleitorais para dois anos, 2004 e 2008.
Spada.Data.Check <- Spada.Data %>% 
  filter(!is.na(partpref) & partpref != "")

table(Spada.Data.Check$year)

rm(Spada.Data.Check)


################## Criando vari�veis extras no banco Spada ##################



# De/Para das vari�veis do banco e do paper:

## Adopt.pb = Adoption of pb,  Dependent Variable of models 1 and 2
## Abandon.pb = Adandon of pb, Dependent Variable of models 3 and 4
## VictoryPTAfter202 = Victory of the PT before 2002 (discrete) * -1
## ChangeEffect2002 = Change in effect after 2002 (discrete)
## mindist == Minimum Distance
## ptwin = Change in effect after 2002 (?)
## taxrevenues == Tax share of revenues
## balsheetrev == Financial viability index
## continuitypartpref == City government continuity (discrete)
## MayorsVulnerability = Mayor's vulnerability
## MayorControlCouncil = Mayor controls the council (discrete)
## legprefpower == Mayor's share of council seats
## YearDummies1996 = Period 3 (1996-2000)
## YearDummies2000 = Period4 (2001-2004)
## YearDummies2004 = Period5 (2005-2008)
## YearDummies2008 = Period 6 (2009-2012)


## Criar a vari�vel dependente
  ### vari�vel de ado��o do pb: Adopt.pb
  ### vari�vel de abandono do pb: Abandon.pb

# Cria vari�vel dependente
DependentVar <- Spada.Data %>% 
  # Seleciona vari�veis relevantes.
  select(codeipea, year, pb) %>% 
  # Seleciona apenas os anos de elei��o
  filter(year %in% c(1992, 1996, 2000, 2004, 2008, 2012, 2016)) %>% 
  # Garante que elas esteja ordenadas por cidade e ano (fundamental para o comando lag).
  arrange(codeipea, year) %>%
  # Cria uma vari�vel para garantir que cada munic�pios � tratado separadamente.
  mutate(sameMunic = ifelse(codeipea == lag(codeipea), 1, 0)) %>% 
  # Vari�vel para os munic�pios que adotaram o OP.
  mutate(Adopt.pb = ifelse(sameMunic == 1 & pb == 1 & lag(pb) == 0, 1, 0)) %>% 
  # Resolve o caso onde o munic�pio adota o pb no primeiro ano da s�rie.
  group_by(codeipea) %>% 
  mutate(Adopt.pb = ifelse(year == min(year) & pb == 1, 1, Adopt.pb)) %>% 
  ungroup() %>% 
  # Vari�vel para os munic�pios que abandonaram o OP.
  mutate(Abandon.pb = ifelse(sameMunic == 1 & pb == 0 & lag(pb) == 1, 1, 0)) %>% 
  # Corrige o primeiro caso, onde n�o existe o lag.
  mutate(Abandon.pb = ifelse(is.na(Abandon.pb), 0, Abandon.pb)) %>% 
  # Deixa apenas as vari�veis de interesse.
  select(codeipea, year, Adopt.pb, Abandon.pb)
  

# Vari�vel Mayor controls the council (discrete)
MayorControlCouncil <- Spada.Data %>% 
  # Seleciona vari�veis relevantes.
  select(codeipea, year, bestveradorparty, partpref) %>%
  # Filtra casos em branco e nulos
  filter(partpref != "" & !is.na(partpref)) %>% 
  # Cria a vari�vel de controle do governo
  mutate(MayorControlCouncil = ifelse(bestveradorparty == partpref, 1, 0)) %>% 
  # Deixa apenas as vari�veis de interesse.
  select(codeipea, year, MayorControlCouncil)


# Vari�veis Change in effect after 2002 (discrete) e Change in effect after 2002.
  ## Vou assumir que a vari�vel Change in effect after 2002 � a vit�ria do PT depois de 2002
ChangeEffect2002 <- Spada.Data %>% 
  # Seleciona vari�veis relevantes.
  select(codeipea, year, ptwin, partpref) %>% 
  # Corrige os casos no banco em que a vari�vel ptwin (vit�ria do PT) � missing (NA).
  mutate(ptwin2 = ifelse(is.na(ptwin), 0, ptwin)) %>% 
  # Cria a vari�vel Change in effect after 2002 (discrete)
  mutate(ChangeEffect2002 = ifelse(year > 2002, 1, 0)) %>% 
  # Cria a variavel de intera��o entre ptwin e Change in effect after 2002 (discrete)
  mutate(VictoryPTAfter202 = ptwin2 * ChangeEffect2002) %>%
  # Deixa apenas as vari�veis de interesse.
  select(codeipea, year, ChangeEffect2002, VictoryPTAfter202)


# Vari�vel Mayor's vulnerability
MayorsVulnerability <- Spada.Data %>% 
  # Seleciona vari�veis relevantes.
  select(codeipea, year, votiprefprim, secbestprefeitovote_ft) %>% 
  # Filtra casos em que n�o h� dados eleitorais.
  filter(!is.na(votiprefprim)) %>% 
  # Cria a vari�vel de vulnerabilidade eleitoral do prefeito 
  # (vota��o do segundo lugar sobre a vota��o do primeiro lugar no primeiro turno).
  mutate(MayorsVulnerability = secbestprefeitovote_ft/votiprefprim) %>% 
  # Deixa apenas as vari�veis de interesse.
  select(codeipea, year, MayorsVulnerability)


# years Dummies
YearDummies <-  factor(Spada.Data$year)
YearDummies <- model.matrix(~YearDummies) %>% 
  as.data.frame() %>% 
  select(-matches("(Intercept)")) %>% 
  cbind(Spada.Data) %>% 
  select(codeipea, year, starts_with("YearDummies"))

names(YearDummies)



# Junta as vari�veis criadas em um �nico banco

Spada.Data.OLS <- Spada.Data %>% 
  ## As linhas abaixo s�o para determinar o munic�pio com mais de 50 mil habitantes no in�cio da s�rie.
  # Seleciona vari�veis usadas
  select(codeipea, year, pop) %>% 
  # Filtra munic�pios-ano com popula��o missing.
  filter(!is.na(pop)) %>% 
  # Agrupo por munic�pio.
  group_by(codeipea) %>%
  # Deixa apenas o ano inicial da s�rie
  filter(year == min(year, na.rm = TRUE)) %>% 
  # Renomeia a vari�vel popula��o para popula��o no in�cio
  rename(PopInicio = pop) %>% 
  # Retira casos onde n�o h� popula��o inicial.
  filter(!is.na(PopInicio)) %>% 
  # Adiciona a vari�vel da popula��o inicial no banco.
  right_join(Spada.Data, by = c("codeipea", "year")) %>% 
  # Agrupa por munic�pio
  group_by(codeipea) %>%
  # Expande o valor da popula��o no in�cio da s�rie para todos os anos.
  mutate(PopInicio = min(PopInicio, na.rm = TRUE)) %>% 
  # Filtra apenas os munic�pios com mais de 50k habitantes no in�cio da s�rie.
  # Tamb�m exclui casos com munic�pios com dados missing de popula��o.
  filter(PopInicio >= 50000 & !is.infinite(PopInicio)) %>%
  # Desagrupa os dados.
  ungroup %>% 
  # Adiciona as vari�veis criadas acima.
  left_join(DependentVar, by = c("codeipea", "year")) %>% 
  left_join(MayorControlCouncil, by = c("codeipea", "year")) %>% 
  left_join(ChangeEffect2002, by = c("codeipea", "year")) %>% 
  left_join(MayorsVulnerability, by = c("codeipea", "year")) %>% 
  left_join(YearDummies, by = c("codeipea", "year")) %>% 
  # Retira o acento, para evitar problemas de enconding.
  rename(Municipio = "Munic�pio") %>% 
  # Seleciona apenas vari�veis relevantes
  select(codeipea, year, Municipio, state, pb, Adopt.pb, Abandon.pb, VictoryPTAfter202, 
         ChangeEffect2002, mindist, ptwin, taxrevenues, balsheetrev, continuitypartpref, 
         MayorsVulnerability, MayorControlCouncil, legprefpower, YearDummies2008, pop)


# Verifica o banco
View(Spada.Data.OLS)
names(Spada.Data.OLS)

rm(DependentVar, MayorControlCouncil, ChangeEffect2002, 
   MayorsVulnerability, YearDummies)


# mais alguns ajustes no banco
Spada.Data.OLS <- Spada.Data.OLS %>% 
  filter(!is.na(MayorsVulnerability))
  
  

glimpse(Spada.Data.OLS)

table(Spada.Data.OLS$Adopt.pb)
table(Spada.Data.OLS$Abandon.pb)
table(Spada.Data.OLS$ptwin)


################## Regress�es utilizando o banco fornecido por Spada ##################

# De/Para das vari�veis do banco e do paper:

## Adopt.pb = Adoption of pb,  Dependent Variable of models 1 and 2
## Abandon.pb = Adandon of pb, Dependent Variable of models 3 and 4
## VictoryPTAfter202 = Victory of the PT before 2002 (discrete) * -1
## ChangeEffect2002 = Change in effect after 2002 (discrete)
## mindist == Minimum Distance
## ptwin = Change in effect after 2002 (?)
## taxrevenues == Tax share of revenues
## balsheetrev == Financial viability index
## continuitypartpref == City government continuity (discrete)
## MayorsVulnerability = Mayor's vulnerability
## MayorControlCouncil = Mayor controls the council (discrete)
## legprefpower == Mayor's share of council seats
## YearDummies1996 = Period 3 (1996-2000)
## YearDummies2000 = Period4 (2001-2004)
## YearDummies2004 = Period5 (2005-2008)
## YearDummies2008 = Period 6 (2009-2012)

# Roda o modelo
LPM.Adopt <- lm(Adopt.pb ~ VictoryPTAfter202 + ChangeEffect2002 + mindist + ptwin +
            taxrevenues + balsheetrev + continuitypartpref + MayorsVulnerability + 
            MayorControlCouncil + legprefpower + YearDummies2008, 
          data = Spada.Data.OLS)

summary(LPM.Adopt)


# A Vari�vel ChangeEffect2002 apresenta somente valores zero, dado que s� temos dados de 2004 e 2008.
# Dado o acima, vari�veis VictoryPTAfter202 e ptwin apresenta multicolineariedade perfeita, vou remover VictoryPTAfter202

LPM.Adopt <- lm(Adopt.pb ~ mindist + ptwin + taxrevenues + balsheetrev + 
                  continuitypartpref + MayorsVulnerability + 
                  MayorControlCouncil + legprefpower + YearDummies2008, 
                data = Spada.Data.OLS)

summary(LPM.Adopt)


# Colocando a popula��o como vari�vel explicativa:

LPM.Adopt <- lm(Adopt.pb ~ pop + mindist + ptwin + taxrevenues + balsheetrev + 
                  continuitypartpref + MayorsVulnerability + 
                  MayorControlCouncil + legprefpower + YearDummies2008, 
                data = Spada.Data.OLS)

summary(LPM.Adopt)



# Agora analisando as chances de abandono do pb:


LPM.Abandon <- lm(Abandon.pb ~ mindist + ptwin + taxrevenues + balsheetrev + 
                  continuitypartpref + MayorsVulnerability + 
                  MayorControlCouncil + legprefpower + YearDummies2008, 
                  data = Spada.Data.OLS)

summary(LPM.Abandon)


# Colocando a popula��o como vari�vel explicativa:

LPM.Abandon <- lm(Abandon.pb ~ pop + mindist + ptwin + taxrevenues + balsheetrev + 
                    continuitypartpref + MayorsVulnerability + 
                    MayorControlCouncil + legprefpower + YearDummies2008, 
                  data = Spada.Data.OLS)

summary(LPM.Abandon)

# Clear memory
rm(LPM.Abandon, LPM.Adopt, Spada.Data.OLS)




################## Tabelas ##################

names(Censo.OP)

# Tabela 01:


Adopted.Op <- Censo.OP %>% 
  mutate(Adopt1992 = pb1992) %>% 
  mutate(Adopt1996 = ifelse(pb1992 == 0 & pb1996 == 1, 1, 0)) %>% 
  mutate(Adopt2000 = ifelse(pb1996 == 0 & pb2000 == 1, 1, 0)) %>%
  mutate(Adopt2004 = ifelse(pb2000 == 0 & pb2004 == 1, 1, 0)) %>% 
  mutate(Adopt2008 = ifelse(pb2004 == 0 & pb2008 == 1, 1, 0)) %>% 
  mutate(Adopt2012 = ifelse(pb2008 == 0 & pb2012 == 1, 1, 0)) %>% 
  mutate(Adopt2016 = ifelse(pb2012 == 0 & pb2016 == 1, 1, 0)) %>% 
  mutate(Abandon1996 = ifelse(pb1992 == 1 & pb1996 == 0, 1, 0)) %>%
  mutate(Abandon2000 = ifelse(pb1996 == 1 & pb2000 == 0, 1, 0)) %>% 
  mutate(Abandon2004 = ifelse(pb2000 == 1 & pb2004 == 0, 1, 0)) %>% 
  mutate(Abandon2008 = ifelse(pb2004 == 1 & pb2008 == 0, 1, 0)) %>%
  mutate(Abandon2012 = ifelse(pb2008 == 1 & pb2012 == 0, 1, 0)) %>%
  mutate(Abandon2016 = ifelse(pb2012 == 1 & pb2016 == 0, 1, 0))


UnbrokeSeq <- function(x) {
  
  x <- x[!is.na(x)]
  
  unbroke <- 0
  
  for (i in seq_along(x)) {
    if(i == 1) {
      if(x[i] != 0){
        unbroke <- unbroke + 1
      }
    } else {
      if(x[i] != 0 & x[i-1] != 0){
        unbroke <- unbroke + 1
      } else {
        unbroke <- 0
      }
      
      if(x[i] != 0 & x[i-1] == 0){
        unbroke <- 1
      }
    }
  }
  return(unbroke)
}


FirstColumn <- which(names(Adopted.Op) == "pb1992")
LastColumnVector <- 3:8
UnbrokenMatrix <- data.frame(matrix(nrow = nrow(Adopted.Op), ncol = 0))

for (i in 1:length(LastColumnVector)) {
  # i <- 1  
  SelectMatrix <- select(Adopted.Op, FirstColumn:LastColumnVector[i])
  UnbrokenSeq <- as.numeric()
  
  for (j in seq_len(nrow(SelectMatrix))) {
    # j <- 1
    UnbrokenSeq[j] <- UnbrokeSeq(as.numeric(SelectMatrix[j,]))
  }
  vectorname <- paste0("Unbroke", names(Adopted.Op)[LastColumnVector[i]])
  UnbrokenMatrix[[vectorname]] <- UnbrokenSeq
}

rm(UnbrokeSeq, SelectMatrix, i, j)
rm(FirstColumn, LastColumnVector, vectorname)
rm(UnbrokenSeq)


Adopted.Op <- cbind(Adopted.Op, UnbrokenMatrix)
rm(UnbrokenMatrix)

View(Adopted.Op)

names(Spada.Data)


Pop92 <- SocioDemoEconomia %>% 
  filter(SocioMunic_Ano == 1992) %>% 
  select(Munic_Id, SocioMunic_Populacao) %>% 
  rename(codeipea = Munic_Id) %>% 
  rename(pop = SocioMunic_Populacao) %>% 
  mutate(pop = as.numeric(pop)) %>% 
  mutate(codeipea = as.numeric(codeipea))


map_chr(Adopted.Op, typeof)
map_chr(Pop92, typeof)

names(Adopted.Op)

Adopted.Op.Table <- as_tibble(Adopted.Op) %>% 
  # Exclui Bras�lia
  filter(codeipea != "5300108") %>% 
  # Considera os valores nulos em pb2016 como sem OP (creio que essa a melhor interpreta��o)
  mutate(pb2016 = ifelse(is.na(pb2016), 0, pb2016)) %>% 
  select(codeipea, name, state, pb1992:pb2016, Adopt1992:Unbrokepb2016) %>% 
  gather(Variable, Var_Value, pb1992:Unbrokepb2016) %>% 
  mutate(year = substr(Variable, nchar(Variable) - 3, nchar(Variable))) %>% 
  mutate(variable2 = substr(Variable, 1, nchar(Variable) - 4)) %>% 
  mutate(year = as.numeric(year)) %>% 
  left_join(Pop92, by = "codeipea") %>% 
  filter(pop > 50000) %>% select(-pop) %>% 
  mutate(variable3 = ifelse(variable2 == "Unbrokepb", paste0("UnbrokenPb_", Var_Value), variable2))


%>%
  group_by(variable2, year) %>% 
  summarise(ValorContagem = sum(Var_Value, na.rm = TRUE)) %>% 
  spread(year, ValorContagem)

table(Adopted.Op.Table$variable2)
table(Adopted.Op.Table$variable3)


head(Adopted.Op.Table)
names(Adopted.Op.Table)
View(Adopted.Op.Table)

rm(Pop92)
rm(Adopted.Op, Adopted.Op.Table)

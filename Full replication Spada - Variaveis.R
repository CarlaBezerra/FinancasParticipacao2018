
# Script para extrair dados do BD para a an�lise das finan�as municipais
# e do probabilidade de sobreviv�ncia do Or�amento Participativo.

# Criado por Murilo Junqueira

# Data cria��o: 2018-05-09
# Ultima modifica��o: 2018-06-06

################## Prepara �rea de trabalho ##################

#clean memory
rm(list=ls(all=TRUE))
gc()


# Os diret�rios de inser��o dos dados Brutos (InputFolder), destino dos 
# dados (OutputFolder) e localiza��o dos scripts (ScriptFolder). Atualize se necess�rio!
InputFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/BD csv/"
OutputFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados An�lise/"
ScriptFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Scripts R/"
SpadaFolder <- "E:/Users/Murilo/Dropbox/Acad�mico e Educa��o/Publica��es/2017 - Participa��o Carla/Dados/Dados Brutos/PBCENSUS Spada/"


# instala o pacote de extra��o dos dados, se necess�rio
library(tidyverse)
library(data.table)
library(readstata13)
library(readxl)
library(scales)



################## Fun��es �teis ##################

# Fun��o para transformar vari�veis de texto para num�rico
# �til para problemas de decimal (30,50 -> 30.50)
CharaterToNumeric <- function(x) {
  x <- sub(",", ".", x)
  x <- as.numeric(x)
  return(x)
}

# Fun��o para transformar vari�veis de texto para inteiro
# �til para problemas de decimal (30,00 -> 30)
CharaterToInteger <- function(x) {
  x <- sub(",", ".", x)
  x <- as.integer(x)
  return(x)
}

################## Load Data ##################


# Spada's Data
Spada.Data <- read.dta13(paste0(SpadaFolder, "PBCENSUS1989_2012data.dta"))


# Basic Municipal Data
Municipios <- fread(paste0(InputFolder, "Municipios.csv"), 
                    sep = ";", dec = ",",
                    stringsAsFactors = FALSE)

# Basic Data about Brazilian States
UFs <- fread(paste0(InputFolder, "UFs.csv"), 
                    sep = ";", dec = ",",
                    stringsAsFactors = FALSE)

# Data about Participatory Budget
MunicOp <- fread(paste0(InputFolder, "MunicOp.csv"), 
                 sep = ";", dec = ",",
                 stringsAsFactors = FALSE)


# Data about candidates
CandidatoAno <- fread(paste0(InputFolder, "CandidatoAno.csv"), 
                      sep = ";", dec = ",",
                      stringsAsFactors = FALSE)


# Finantial Data
MunicFinancas <- fread(paste0(InputFolder, "MunicFinancas.csv"), 
                       sep = ";", dec = ",",
                       stringsAsFactors = FALSE)


# Socioeconomic Data
SocioDemoEconomia <- fread(paste0(InputFolder, "SocioDemoEconomia.csv"), 
                           sep = ";", dec = ",",
                           stringsAsFactors = FALSE)


################## Contru��o de Vari�veis a partir de banco pr�prio ##################

# Empty data frame to gather all variables
Data.Analisys <- data.frame()

# Municipalities basic information (name, state and region)
Data.Analisys <- Municipios %>% 
  left_join(UFs, by = "UF_Id") %>% 
  select(Munic_Id, Munic_Nome, UF_Sigla, UF_Regiao)


# Free memory
rm(Municipios, UFs)

# From/to dataset variables.

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


#### Adopt.pb = Adoption of pb,  Dependent Variable of models 1 and 2
#### Abandon.pb = Adandon of pb, Dependent Variable of models 3 and 4

Data.Analisys <- Data.Analisys %>% 
  # Join basic municipal data
  right_join(MunicOp, by = "Munic_Id") %>% 
  # Translate variable to English
  rename(year = MunicOp_Ano) %>% 
  # Filter year range
  filter(year >= 1992 & year <= 2012) %>% 
  # Order the rows by muncipality and year
  arrange(Munic_Id, year) %>% 
  # Create the variable of adoption of participatory budget
  mutate(Adopt.pb = ifelse(Munic_Id == lag(Munic_Id) & MunicOP_OP == 1 & lag(MunicOP_OP) == 0, 1, 0)) %>% 
  # Corret the case of the municipalities the adopted pb in the first year of the series.
  group_by(Munic_Id) %>% 
  mutate(Adopt.pb = ifelse(year == min(year) & MunicOP_OP == 1, 1, Adopt.pb)) %>% 
  ungroup() %>% 
  # Create the variable of abandon of participatory budget
  mutate(Abandon.pb = ifelse(Munic_Id == lag(Munic_Id) & MunicOP_OP == 0 & lag(MunicOP_OP) == 1, 1, 0)) %>% 
  # Corret the case of the first municipality of the dataset (that doesn't have lag)
  mutate(Abandon.pb = ifelse(is.na(Abandon.pb), 0, Abandon.pb))
  

# check the data
names(Data.Analisys)
head(Data.Analisys)
# View(Data.Analisys)

# Free memory
rm(MunicOp)


#### VictoryPTAfter202 = Victory of the PT before 2002 (discrete) * -1

# Filtering only the elected mayors among all candidates
ElectedMayors <- CandidatoAno %>% 
  # Select mayor candidates
  filter(CandAno_Cargo == "P")%>% 
  # In variable CandAno_SituacaoElec (electoral situation) 1 means elected candidate 
  filter(CandAno_SituacaoElec == 1) %>%
  # Translate variables
  rename(year = CandAno_Ano) %>% 
  rename(MayorName = CandAno_Nome) %>% 
  rename(MayorParty = Partido_Sigla) %>% 
  rename(MayorElecNumber = CandAno_Numero) %>% 
  # Select relevant variables
  select(Munic_Id, year, MayorName, MayorElecNumber, MayorParty)



# Create the variable ptwin
Data.Analisys <- Data.Analisys %>% 
  left_join(ElectedMayors, by = c("Munic_Id", "year")) %>% 
  mutate(ptwin = ifelse(MayorParty == "PT", 1, 0))


# check the data
names(Data.Analisys)
head(Data.Analisys)
# View(Data.Analisys)




# ChangeEffect2002 = Change in effect after 2002 (discrete)

Data.Analisys <- Data.Analisys %>% 
  mutate(ChangeEffect2002 = ifelse(year > 2002, 1, 0))


# mindist == Minimum Distance

Distance.Data <- Spada.Data %>% 
  select(codeipea, year, mindist) %>%
  rename(Munic_Id = codeipea)
  

# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  left_join(Distance.Data, by = c("Munic_Id", "year")) 

rm(Distance.Data)



# ptwin = Change in effect after 2002 (?)
  ## I will assume that this variable is the interaction term between ptwin and ChangeEffect2002

Data.Analisys <- Data.Analisys %>% 
  mutate(VictoryPTAfter202 = ptwin * ChangeEffect2002)



# taxrevenues == Tax share of revenues
  ## taxrevenues == Tax revenue / (current revenue - current revenue deductions)
  ## taxrevenues == Receita Tribut�ria / (Receitas Correntes - dedu��es de receitas correntes)

TaxShareRevenues <- MunicFinancas %>% 
  # Translade variable
  rename(year = MunicFinancas_Ano) %>% 
  # Filter missing municipality codes.
  filter(!is.na(Munic_Id)) %>% 
  # Prevent character/numeric intepretation problems
  mutate(ContasPublica_Id = as.integer(ContasPublica_Id)) %>%
  mutate(MunicFinancas_ContaValor = sub(",", ".", MunicFinancas_ContaValor)) %>% 
  mutate(MunicFinancas_ContaValor = as.numeric(MunicFinancas_ContaValor)) %>% 
  # Select the used accounts (Tax revenue, current revenue, current revenue deductions)
  filter(ContasPublica_Id == 10000000 | ContasPublica_Id == 11000000 | 
           ContasPublica_Id == 900000000) %>% 
  # Spread account variables
  spread(ContasPublica_Id, MunicFinancas_ContaValor) %>% 
  # Set friendly variable's names.
  rename(CurrentRevenue = "10000000", 
         TaxRevenues = "11000000",
         RevenueDeductions = "900000000") %>% 
  # remove NA from deductions before 2002
  mutate(RevenueDeductions = ifelse(is.na(RevenueDeductions), 0, RevenueDeductions)) %>% 
  # Create taxrevenues variables
  mutate(taxrevenues = TaxRevenues / (CurrentRevenue - RevenueDeductions)) %>% 
  # Select relevant variables
  select(Munic_Id, year, taxrevenues)
  

# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("taxrevenues") ) %>% 
  # add new variable
  left_join(TaxShareRevenues, by = c("Munic_Id", "year")) 

# Free memory
rm(TaxShareRevenues)


# balsheetrev == Financial viability index
  ## balsheetrev == (Current Spending + Capital Spending) / (Current revenue - current revenue deductions + Capital Revenue)
  ## balsheetrev == (Receita Tribut�ria + Receita de Capital) / (Receitas Correntes - dedu��es de receitas correntes + Receita de Capital)

BalanceBudget <- MunicFinancas %>% 
  # Translade variable
  rename(year = MunicFinancas_Ano) %>% 
  # Filter missing municipality codes.
  filter(!is.na(Munic_Id)) %>% 
  # Prevent character/numeric intepretation problems
  mutate(ContasPublica_Id = as.integer(ContasPublica_Id)) %>%
  mutate(MunicFinancas_ContaValor = sub(",", ".", MunicFinancas_ContaValor)) %>% 
  mutate(MunicFinancas_ContaValor = as.numeric(MunicFinancas_ContaValor)) %>% 
  # Select the used accounts (Current Spending, Capital Spending, Current revenue, current revenue deductions, Capital Revenue)
  filter(ContasPublica_Id == 10000000 | ContasPublica_Id == 20000000 |
           ContasPublica_Id == 900000000 | ContasPublica_Id == 30000000 |
           ContasPublica_Id == 40000000) %>% 
  # Spread account variables
  spread(ContasPublica_Id, MunicFinancas_ContaValor) %>% 
  # Set friendly variable's names.
  rename(CurrentRevenue = "10000000", 
         CapitalRevenue = "20000000",
         RevenueDeductions = "900000000",
         CurrentSpending = "30000000", 
         CapitalSpending = "40000000") %>% 
  # remove NA from deductions before 2002
  mutate(RevenueDeductions = ifelse(is.na(RevenueDeductions), 0, RevenueDeductions)) %>% 
  # Create balsheetrev variable
  mutate(balsheetrev = (CurrentSpending + CapitalSpending) / (CurrentRevenue - RevenueDeductions + CapitalRevenue)) %>% 
  # Select relevant variables
  select(Munic_Id, year, balsheetrev)

# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("balsheetrev") ) %>% 
  # add new variable
  left_join(BalanceBudget, by = c("Munic_Id", "year")) 

# Free memory
rm(BalanceBudget)


# continuitypartpref == City government continuity (discrete)


ContinuityMayor <- CandidatoAno %>% 
  # Select mayor candidates
  filter(CandAno_Cargo == "P") %>% 
  # In variable CandAno_SituacaoElec (electoral situation) 1 means elected candidate 
  filter(CandAno_SituacaoElec == 1) %>%
  # Translate variables
  rename(year = CandAno_Ano) %>% 
  rename(MayorName = CandAno_Nome) %>%
  rename(MayorElecNumber = CandAno_Numero) %>% 
  # Order the dataset rows by municipality and year
  arrange(Munic_Id, year) %>% 
  ## Remove accents
  mutate(MayorName.norm = iconv(MayorName, to = "ASCII//TRANSLIT")) %>% 
  # Create the continuitypartpref variable
  mutate(ContinuityMayor = ifelse(MayorName.norm == lag(MayorName.norm) & Munic_Id == lag(Munic_Id), 1, 0)) %>% 
  mutate(continuitypartpref = ifelse(MayorElecNumber == lag(MayorElecNumber) & Munic_Id == lag(Munic_Id), 1, 0)) %>% 
  # In the first year of the series, there is no continuity
  mutate(ContinuityMayor = ifelse(is.na(ContinuityMayor), 0, ContinuityMayor)) %>% 
  mutate(continuitypartpref = ifelse(is.na(continuitypartpref), 0, continuitypartpref)) %>% 
  # Select relevant variables
  select(Munic_Id, year, ContinuityMayor, continuitypartpref)


# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("ContinuityMayor"), -starts_with("continuitypartpref")) %>% 
  # add new variable
  left_join(ContinuityMayor, by = c("Munic_Id", "year")) 

# Free memory
rm(ContinuityMayor)


# MayorsVulnerability = Mayor's vulnerability

# Recicle the ElectedMayors dataset (above)

MayorsVul <- CandidatoAno %>% 
  # Debug line:
  # filter(Munic_Id == 3550308) %>% 
  # Select mayor candidates
  filter(CandAno_Cargo == "P") %>% 
  # Avoid character/number problems
  mutate(CandAno_QtVotos = as.integer(CandAno_QtVotos)) %>% 
  mutate(CandAno_SituacaoElec = as.integer(CandAno_SituacaoElec)) %>% 
  # Filter only first round
  filter(CandAno_Turno == 1) %>%
  # Filter null and blank vontes
  filter(CandAno_SituacaoElec > -6) %>% 
  # Translate variables
  rename(year = CandAno_Ano) %>% 
  rename(CandidateName = CandAno_Nome) %>%
  rename(CandidateNumber = CandAno_Numero) %>% 
  # Find the top two candidates
  group_by(Munic_Id, year) %>%
  arrange(Munic_Id, desc(CandAno_QtVotos)) %>% 
  slice(1:2)  %>% 
  # Join the elected mayors dataset. Recicle the ElectedMayors dataset (above).
  left_join(ElectedMayors, by = c("Munic_Id", "year")) %>% 
  mutate(ElectedVotes.temp = ifelse(CandidateNumber == MayorElecNumber, CandAno_QtVotos, NA)) %>% 
  mutate(RunnerUpVotes.temp = ifelse(CandidateNumber != MayorElecNumber, CandAno_QtVotos, NA)) %>% 
  summarise(ElectedVotes = mean(ElectedVotes.temp, na.rm = TRUE),
            RunnerUpVotes = mean(RunnerUpVotes.temp, na.rm = TRUE)) %>% 
  mutate(MayorsVulnerability = RunnerUpVotes/ElectedVotes) %>% 
  # Select relevant variables
  select(Munic_Id, year, MayorsVulnerability)


# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("MayorsVulnerability")) %>% 
  left_join(MayorsVul, by = c("Munic_Id", "year")) 

# Free memory
rm(MayorsVul)


# legprefpower == Mayor's share of council seats
# MayorControlCouncil = Mayor controls the council (discrete)

# Find the party that have the bigger number of seats in each election.
MajorCouncilParty <- CandidatoAno %>% 
  # Translate variables
  rename(year = CandAno_Ano) %>% 
  # mutate(Munic_Id = as.integer(Munic_Id)) %>% 
  # Debug line:
  # filter(Munic_Id == 3550308) %>% 
  # Select Council candidates.
  filter(CandAno_Cargo == "V") %>% 
  # Select elected council members.
  ## 1 means elected by her own votes.
  ## 5 means elected by party votes.
  filter(CandAno_SituacaoElec == 1 | CandAno_SituacaoElec == 5) %>% 
  # Find Party number
  mutate(PartyNumber = substr(as.character(CandAno_Numero), 1, 2)) %>%
  mutate(PartyNumber = as.integer(PartyNumber)) %>% 
  # Find the nunber of seats for each party
  group_by(Munic_Id, year, PartyNumber) %>% 
  summarise(PartySeats = n()) %>%
  # Find total number of seats
  group_by(Munic_Id, year) %>% 
  mutate(CityTotalSeats = sum(PartySeats)) %>% 
  # Party share of seats.
  mutate(PartyShareSeats = PartySeats/CityTotalSeats) %>% 
  # Find the share of mayors party. Recicle elected mayors dataset.
  left_join(ElectedMayors, by = c("Munic_Id", "year")) %>%
  mutate(legprefpower.temp = ifelse(PartyNumber == MayorElecNumber, PartyShareSeats, NA)) %>% 
  # Create the variables legprefpower and MayorControlCouncil
  summarise(legprefpower = mean(legprefpower.temp, na.rm = TRUE)) %>% 
  ## This line is for the case that mayors party doesn't have any seat in the council
  mutate(legprefpower = ifelse(is.nan(legprefpower), 0, legprefpower)) %>% 
  mutate(MayorControlCouncil = ifelse(legprefpower >= .5, 1, 0))
  
  
# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  select(-starts_with("MayorControlCouncil"), -starts_with("legprefpower")) %>% 
  left_join(MajorCouncilParty, by = c("Munic_Id", "year")) 

names(Data.Analisys)

# Free memory
rm(MajorCouncilParty)


# YearDummies*

YearDummies <-  factor(Data.Analisys$year)
YearDummies <- model.matrix(~YearDummies) %>% 
  as.data.frame() %>% 
  select(-matches("(Intercept)")) %>% 
  cbind(Data.Analisys) %>% 
  select(Munic_Id, year, starts_with("YearDummies"))

# Check data
names(YearDummies)

# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("YearDummies")) %>% 
  left_join(YearDummies, by = c("Munic_Id", "year")) 

# Check data
names(Data.Analisys)

rm(YearDummies)


# Population and GDP per capita

Economics.Data <- SocioDemoEconomia %>% 
  # Translate variables
  rename(year = SocioMunic_Ano) %>% 
  rename(population = SocioMunic_Populacao) %>% 
  rename(GDP = SocioMunic_PIB) %>% 
  #Prevent data type error
  mutate(Munic_Id = CharaterToInteger(Munic_Id)) %>% 
  mutate(year = CharaterToInteger(year)) %>% 
  mutate(population = CharaterToInteger(population)) %>% 
  mutate(GDP = CharaterToNumeric(GDP)) %>% 
  # GDP per capita
  mutate(GDPpp = GDP / population) 

Data.Analisys <- Data.Analisys %>% 
  select(-starts_with("population"), -starts_with("GDP")) %>% 
  left_join(Economics.Data, by = c("Munic_Id", "year"))



################## Paper's new variables ##################


SocioDemoEconomia <- SocioDemoEconomia %>% mutate(Munic_Id = as.integer(Munic_Id))
MunicFinancas <- MunicFinancas %>% mutate(Munic_Id = as.integer(Munic_Id))



# Public investment

Investment <- MunicFinancas %>% 
  # Translade variable
  rename(year = MunicFinancas_Ano) %>% 
  # Filter missing municipality codes.
  filter(!is.na(Munic_Id)) %>% 
  # Prevent character/numeric intepretation problems
  mutate(ContasPublica_Id = as.integer(ContasPublica_Id)) %>%
  mutate(MunicFinancas_ContaValor = sub(",", ".", MunicFinancas_ContaValor)) %>% 
  mutate(MunicFinancas_ContaValor = as.numeric(MunicFinancas_ContaValor)) %>% 
  # Select the used accounts (Current Spending, Capital Spending, Current revenue, current revenue deductions, Capital Revenue)
  filter(ContasPublica_Id == 10000000 | ContasPublica_Id == 20000000 |
           ContasPublica_Id == 900000000 | ContasPublica_Id == 30000000 |
           ContasPublica_Id == 40000000 | ContasPublica_Id == 44000000) %>% 
  # Spread account variables
  spread(ContasPublica_Id, MunicFinancas_ContaValor) %>% 
  # Set friendly variable's names.
  rename(CurrentRevenue = "10000000", 
         CapitalRevenue = "20000000",
         RevenueDeductions = "900000000",
         CurrentSpending = "30000000", 
         CapitalSpending = "40000000",
         InvestimentTotal = "44000000") %>% 
  # remove NA from deductions before 2002
  mutate(RevenueDeductions = ifelse(is.na(RevenueDeductions), 0, RevenueDeductions)) %>% 
  # Join socio economic data
  left_join(SocioDemoEconomia, by = c("Munic_Id" = "Munic_Id", "year" = "SocioMunic_Ano")) %>% 
  # Translate variables
  rename(population =  SocioMunic_Populacao) %>% 
  # Create main variables
  ## Investiment per capita
  mutate(Investpp = InvestimentTotal /population ) %>% 
  mutate(InvestPer = InvestimentTotal / (CurrentSpending - RevenueDeductions + CapitalSpending)) %>% 
  select(Munic_Id, year, Investpp, InvestPer)
  

# Join data in the main dataset
Data.Analisys <- Data.Analisys %>% 
  # Avoid duplicated variables
  select(-starts_with("Investpp"), -starts_with("InvestPer")) %>% 
  # add new variable
  left_join(Investment, by = c("Munic_Id", "year")) 



# Check data
names(Data.Analisys)


## avoid city duplication
Data.Analisys <- Data.Analisys %>% 
  distinct(Munic_Id, year, .keep_all = TRUE)


# Write dataset file
write.table(Data.Analisys, file = paste0(OutputFolder, "Data.Analisys.csv"),
            sep = ";", dec = ",", 
            row.names=FALSE, append = FALSE)

rm(ElectedMayors)


# End
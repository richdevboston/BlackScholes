# ------------------------------ Imports and Sourcing ------------------------------------- #

library(shiny)
library(shinyjs)
library(pracma)
library(tidyverse)
library(plotly)
library(Hmisc)
library(glue)

source("C:\\Users\\Tyler\\PycharmProjects\\BlackScholes\\src\\utils\\greeks.R")
source("C:\\Users\\Tyler\\PycharmProjects\\BlackScholes\\src\\utils\\pricing.R")
source("C:\\Users\\Tyler\\PycharmProjects\\BlackScholes\\src\\utils\\plcharts.R")
source("C:\\Users\\Tyler\\PycharmProjects\\BlackScholes\\src\\utils\\GreekSurface.R")

# ---------------------------------- App Code ---------------------------------- #

ui <- fluidPage(
  
  titlePanel("BlackScholes Options Dashboard"),

    mainPanel(
      tabsetPanel(
        
        # Greek Surface Panel
        tabPanel("Greek Surface",
                 sidebarLayout(
                   sidebarPanel(
                     textInput("strike", label = "Strike Price", value = 1),
                     textInput("rfr", label = "'Risk-free' Rate", value = 0.05),
                     textInput("vol", label = "Volatility", value = 0.13),
                     sliderInput('maturity', "Maturity",
                                 min=1, max=365, value = 90,
                                 sep="", step=15),
                     sliderInput('money_range', "Moneyness",
                                 min=0, max=2, value = c(0.5, 1.5),
                                 sep="", step=0.1),
                     uiOutput("greekType"),
                     radioButtons('greekOrder', "Order",
                                  choices=c("First","Second","Third"),
                                  selected="First"),
                     radioButtons('contract', label="Contract Type",
                                  choices=c("Call","Put"),
                                  selected='Call')
                   ),
                   mainPanel(withSpinner(plotlyOutput("greekplot", width="150%", height="175%")), verbatimTextOutput("surfaceHelp")))
        ),
        
        # P/L Chart Panel
        tabPanel("P/L Chart", sidebarLayout(
          sidebarPanel(
            radioButtons('stratType', "Strategy Type",
                         choices=c("Bullish","Bearish",
                                   "Neutral","Volatility")),
          uiOutput("strategies")
        ), mainPanel(plotOutput("pl_plot")))),
        
        # Pricing Panel
        tabPanel("Pricing", sidebarLayout(
          sidebarPanel(
            textInput("spot", "Spot Price",
                      value = 50),
            textInput("ttm", "Time to Maturity (Years)",
                      value = 50),
            textInput("strike", "Strike Price",
                      value = 50),
            textInput("rfr", "Spot Price",
                      value = 50),
            radioButtons('pricing_contract', "Contract Type",
                         choices=c("Call","Put")),
            uiOutput("priceInput"),
                         
            uiOutput("impVol")
          ),
          mainPanel(plotlyOutput("volsurface", width="150%", height="175%"))),
                 
                 tableOutput("pricing")),
        
        
        tabPanel("Strategy Planner", uiOutput('strategy'))
      )
    )
  
  
)

server <- function(input, output, session) {
  
  # Greek Surface Tab
  output$greekType <- renderUI({
    
    possible_greeks <- as.tibble(t(as.data.frame(list(
      c('First', "Delta"),
      c('First', "Vega"),
      c('First', "Theta"),
      c('First',"Rho"),
      c("Second","Gamma"),
      c("Second","Vanna"),
      c("Second","Charm"),
      c("Second","Vomma"),
      c("Second","Veta"),
      c("Third","Colour"),
      c("Third","Zomma"),
      c("Third","Thega"),
      c("Third","Speed"),
      c("Third","Ultima")))))
    
    names(possible_greeks) <- c('order', 'greek')
    
    selectInput("greek", "Greek",
                choices=filter(possible_greeks, 
                               order==input$greekOrder)$greek)
  })
  
  react_z <- reactive({
    contract <- tolower(input$contract)
    greek <- tolower(input$greek)
    strike <- as.numeric(input$strike)
    vol <- as.numeric(input$vol)
    rfr <- as.numeric(input$rfr)
    money_range=c(input$money_range[1], input$money_range[2])
    
    greekSurface(order=input$greekOrder, greek=greek, contract=contract, strike=strike, vol=vol, rfr=rfr,
                 maturity=input$maturity, money_range=money_range)$Z
  })
  
  
  
  output$greekplot <- renderPlotly({
    
    greek <- tolower(input$greek)
    strike <- as.numeric(input$strike)
    vol <- as.numeric(input$vol)
    rfr <- as.numeric(input$rfr)
    money_range=c(input$money_range[1], input$money_range[2])
    
    
    ## Moneyness will need to be determined based on the contract type I think, unless I can find a way to just change labels and
    ## not the values underlying the calculation.
    
    moneyness <-  seq(from=strike*input$money_range[1],
                      to=strike*input$money_range[2],by=(strike*input$money_range[2] - strike*input$money_range[1])/100)
    
    maturities <- seq(from=1, to=input$maturity ,by=1)
    
    grid <- meshgrid(x=moneyness, y=maturities)
    
    
    d1 <- calc_d(grid, strike, vol, rfr)
    d2 <- d1 - vol*sqrt(grid$Y)
    
    plot_ly(z = ~react_z()) %>% layout(
      title = glue("{capitalize(greek)} Surface"),
      scene = list(
        xaxis = list(title = "Moneyness"),
        yaxis = list(title = "Maturity"),
        zaxis = list(title = glue("{capitalize(greek)}"))
      )) %>%  add_surface(x=grid$X, y=grid$Y) 
  })
  
  output$surfaceHelp <- renderText({
    print(glue("The above surface is the {input$greek} surface for a {input$contract}.
               

               
               In a later version of this app, there will be details regarding the interpretation of the above surface, and how it relates to other greek surfaces, along with some smaller plots of lower order greeks if applicable."))
  })
  
  # Snap to viewpoint buttons -- constrained navigation
  # 
  
  # P/L Chart Tab
  output$strategies <- renderUI({
    all_strats <- as.tibble(t(as.data.frame(list(
      c('Bullish', "Long Call"),
      c("Bullish", "Bull Call Spread"),
      c("Bullish", "Bull Put Spread"),
      c("Bullish","Covered Call"),
      c("Bullish","Married Put"),
      c("Bullish","Secured Short Put"),
      c("Bearish","Long Put"),
      c("Bearish","Bear Put Spread"),
      c("Bearish","Bear Call Spread"),
      c("Neutral","Collar"),
      c("Neutral","Short Straddle"),
      c("Neutral","Short Strangle"),
      c("Neutral","Iron Condor"),
      c("Neutral","Calendar Spread"),
      c("Neutral","Covered Strangle"),
      c("Neutral","Long Call Butterfly"),
      c("Volatility","Long Straddle"),
      c("Volatility","Long Strangle"),
      c("Volatility","Call Backspread"),
      c("Volatility","Put Backspread")))))
    
    names(all_strats) <- c('strat_type', 'Strategy')
    
    selectInput('strategy', "Strategy",
                choices=select(filter(all_strats, strat_type==input$stratType), Strategy))
  })
  
  
  output$plchart <- renderPlot({
    moneyness
    
  })
  
  
  # Pricing Tab
  
  # Goal is to have pricing/implied vol update when the other is changed.
  # Maybe add a reload button?
  output$priceInput <- renderUI({
    pricing_contract <- tolower(input$pricing_contract)
    spot <- as.numeric(input$spot)
    ttm <- as.numeric(input$ttm)
    strike <- as.numeric(input$strike)
    rfr <- as.numeric(input$rfr)
    
    tagList(
      
      textInput("optionPrice", "Option Price",
                  value = priceOption(pricing_contract, strike, spot, ttm, vol, rfr))
     )})
  
  output$impVol <- renderUI({
    pricing_contract <- tolower(input$pricing_contract)
    spot <- as.numeric(input$spot)
    ttm <- as.numeric(input$ttm)
    strike <- as.numeric(input$strike)
    rfr <- as.numeric(input$rfr)
    optionPrice <- as.numeric(input$optionPrice)
    
    tagList(
      
    textInput("pricing_vol", "(Implied) Volatility",
              value=implied_vol(optionPrice, pricing_contract, spot, ttm))
  )})
  
  # Implied volatility surface
  output$volsurface <- renderPlotly({
    pricing_contract <- tolower(input$pricing_contract)
    optionPrice <- as.numeric(input$optionPrice)
    maturities <-  seq(from=1, to=100, by=1)
    price_range <- seq(from=-optionPrice*3, to=optionPrice*3,
                       by=0.1)
    grid <- meshgrid(x=price_range, y=maturities)
    spot <- as.numeric(input$spot)
    
    Z <- implied_vol(grid$X, pricing_contract, spot, grid$Y)
    
    # layout(add_surface(plot_ly(z = ~Z), x=grid$X, y=grid$Y),
    #        xaxis=list(title="Moneyness"), yaxis=list(title="Maturity"), zaxis=list(title="Delta"))
    plot_ly(z = ~Z) %>% layout(
      title = "Implied Volatility Surface",
      scene = list(
        xaxis = list(title = "Price"),
        yaxis = list(title = "DTM"),
        zaxis = list(title ="IV")
      )) %>%  add_surface(x=grid$X, y=grid$Y)
  })
  
  
  # Strategy Builder tab
  output$strategy <- renderUI({
    
  })
  
}

shinyApp(ui, server)

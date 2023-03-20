section IdentityManagerAzure;

logout_uri = "https://login.microsoftonline.com/logout.srf";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";

windowWidth = 720;
windowHeight = 500;
 
[DataSource.Kind="IdentityManagerAzure", Publish="IdentityManagerAzure.Publish"]
shared IdentityManagerAzure.Contents = Value.ReplaceType(ContentsImpl, AuthType);

AuthType = type function(
     AppServerURL as (type text meta [
        Documentation.FieldCaption = "Application Server URL",
        Documentation.FieldDescription = "URL to One Identity Application Server",
        Documentation.SampleValues = {"https://websrv.local/AppServer"}
     ]),
    IssuerAuthUrl as (type text meta [
        Documentation.FieldCaption = "Authorization URL",
        Documentation.FieldDescription = "Required for OAuth 2.0",
        Documentation.SampleValues = {"https://login.microsoftonline.com/000ac08f-bcb7-4e5b-9ebf-cd0052e4b500/oauth2/v2.0/authorize"}
    ]),
    IssuerTokenUrl as (type text meta [
        Documentation.FieldCaption = "Token URL",
        Documentation.FieldDescription = "Required for OAuth 2.0",
        Documentation.SampleValues = {"https://login.microsoftonline.com/000ac08f-bcb7-4e5b-9ebf-cd0052e4b500/oauth2/v2.0/token"}
    ]),
    ClientID as (type text meta [
        Documentation.FieldCaption = "Client ID",
        Documentation.FieldDescription = "Required for OAuth 2.0",
        Documentation.SampleValues = {"80cba6a5-bef4-4aad-a2bc-4bf76cc051cd"}
    ]),
    ClientSecret as (type text meta [
        Documentation.FieldCaption = "Client Secret",
        Documentation.FieldDescription = "Required for OAuth 2.0",
        Documentation.SampleValues = {"hJD8Q~sOysYOFUpX0FSMhN6A2mxqcE~pX7ZShcSY"}
    ])
    )
    as table meta [
        Documentation.Name = "Identity Manager Azure OAuth2 Connector"
    ];

ContentsImpl = (AppServerURL as text, IssuerAuthUrl as text, IssuerTokenUrl as text, ClientID as text, ClientSecret as text) =>
    let        
        _finalUrl = AppServerURL & "/api/doc",
        _host = Uri.Parts(AppServerURL)[Host],
        _swaggerDefinition = Json.Document(Web.Contents(_finalUrl)),
        _swaggerDefinitionWithHost = Record.AddField(_swaggerDefinition, "host", _host),
        source = OpenApi.Document(Binary.From(Json.FromValue(_swaggerDefinitionWithHost)))
    in
        source;

// Data Source definition
IdentityManagerAzure = [
    TestConnection = (AppServerURL,IssuerAuthUrl,IssuerTokenUrl,ClientID,ClientSecret) => { "IdentityManagerAzure.Contents", AppServerURL,IssuerAuthUrl,IssuerTokenUrl,ClientID,ClientSecret },

    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout,
            Label = "OAuth 2.0"
        ]
    ],

    Label = Extension.LoadString("DataSourceLabel")
];

//OAuth2 Login Method
StartLogin = (resourceUrl, state, display) =>
    let
        inputData = Json.Document(resourceUrl),
        clientId = inputData[ClientID],
        authUrl = inputData[IssuerAuthUrl],
        authorizeUrl = authUrl & "?" & Uri.BuildQueryString([
            response_type = "code",
            scope = "openid email",
            client_id = clientId,  
            redirect_uri = redirect_uri,
            state = state
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

//OAuth2 Finish Login Method
FinishLogin = (clientApplication, resourceUrl, context, callbackUri, state) =>
    let        
        parts = Uri.Parts(callbackUri)[Query],
        
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod(resourceUrl, "authorization_code", "code", parts[code])
    in
        result;

//OAuth2 Refresh Token Method
Refresh = (resourceUrl, refresh_token) => TokenMethod(resourceUrl, "refresh_token", "refresh_token", refresh_token);

//OAuth2 Logout Method
Logout = (clientApplication, resourceUrl, accessToken) => logout_uri ;
            
//OAuth2 Token retrieval
TokenMethod = (resourceUrl, grantType, tokenField, code) =>
    let
        inputData = Json.Document(resourceUrl),
        clientId = inputData[ClientID],
        clientSecret = inputData[ClientSecret],
        tokenUrl =  inputData[IssuerTokenUrl],
        queryString = [
            grant_type = "authorization_code",
            redirect_uri = redirect_uri,
            client_id = clientId,
            client_secret = clientSecret
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),
        
        tokenResponse = Web.Contents(tokenUrl,  [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

IdentityManagerAzure.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/OneIdentity/IdentityManager.PowerBI",
    SourceImage = IdentityManagerAzure.Icons,
    SourceTypeImage = IdentityManagerAzure.Icons
];

IdentityManagerAzure.Icons = [
    Icon16 = { Extension.Contents("IdentityManager16.png"), Extension.Contents("IdentityManager20.png"), Extension.Contents("IdentityManager24.png"), Extension.Contents("IdentityManager32.png") },
    Icon32 = { Extension.Contents("IdentityManager32.png"), Extension.Contents("IdentityManager40.png"), Extension.Contents("IdentityManager48.png"), Extension.Contents("IdentityManager64.png") }
];
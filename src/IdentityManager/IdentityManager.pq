section IdentityManager;

client_id = "00000000-0000-0000-0000-000000000000";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri_part = "/oauth2/token";
authorize_uri_part = "/Login";
logout_uri_part = "/Login?wa=wsignout1.0";

windowWidth = 720;
windowHeight = 500;
 
[DataSource.Kind="IdentityManager", Publish="IdentityManager.Publish"]
shared IdentityManager.Contents = Value.ReplaceType(ContentsImpl, AuthType);

AuthType = type function(
     AppServerURL as (type text meta [
        Documentation.FieldCaption = "Application Server URL",
        Documentation.FieldDescription = "URL to One Identity Application Server",
        Documentation.SampleValues = {"https://websrv.local/AppServer"}
     ]),
    IssuerAuthUrl as (type text meta [
        Documentation.FieldCaption = "RSTS Server URL",
        Documentation.FieldDescription = "URL to One Identity Redistributable Secure Token Server (RSTS). Required for OAuth 2.0",
        Documentation.SampleValues = {"https://websrv.local/RSTS"}
    ])
    )
    as table meta [
        Documentation.Name = "Identity Manager RSTS OAuth2 Connector"
    ];

ContentsImpl = (AppServerURL as text, IssuerAuthUrl as text) =>
    let        
        _finalUrl = Diagnostics.LogValue("Final URL", AppServerURL & "/api/doc"),
        _host = Diagnostics.LogValue("Host", Uri.Parts(AppServerURL)[Host]),
        _swaggerDefinition = Json.Document(Web.Contents(_finalUrl)),
        _swaggerDefinitionWithHost = Record.AddField(_swaggerDefinition, "host", _host),
        source = OpenApi.Document(Binary.From(Json.FromValue(_swaggerDefinitionWithHost)))
    in
        source;

// Data Source definition
IdentityManager = [
    TestConnection = (AppServerURL, IssuerAuthUrl) => { "IdentityManager.Contents", AppServerURL, IssuerAuthUrl },

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
        authorizeUrl = inputData[IssuerAuthUrl] & authorize_uri_part & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,  
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
Logout = (clientApplication, resourceUrl, accessToken) => Json.Document(resourceUrl)[IssuerAuthUrl] & logout_uri_part ;
            
//OAuth2 Token retrieval
TokenMethod = (resourceUrl, grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = "authorization_code",
            redirect_uri = redirect_uri,
            client_id = client_id
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        inputData = Json.Document(resourceUrl),
        tokenResponse = Web.Contents(inputData[IssuerAuthUrl] & token_uri_part,  [
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

IdentityManager.Publish = [
    Beta = false,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://github.com/OneIdentity/IdentityManager.PowerBI",
    SourceImage = IdentityManager.Icons,
    SourceTypeImage = IdentityManager.Icons
];

IdentityManager.Icons = [
    Icon16 = { Extension.Contents("IdentityManager16.png"), Extension.Contents("IdentityManager20.png"), Extension.Contents("IdentityManager24.png"), Extension.Contents("IdentityManager32.png") },
    Icon32 = { Extension.Contents("IdentityManager32.png"), Extension.Contents("IdentityManager40.png"), Extension.Contents("IdentityManager48.png"), Extension.Contents("IdentityManager64.png") }
];

// Taken from: https://github.com/microsoft/DataConnectors/blob/master/samples/TripPin/8-Diagnostics/TripPin.pq
// 
// Load common library functions
//

// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
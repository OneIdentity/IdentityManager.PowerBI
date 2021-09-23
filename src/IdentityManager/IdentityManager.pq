section IdentityManager;

client_id = "00000000-0000-0000-0000-000000000000";
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://w1/RSTS/oauth2/token";
authorize_uri = "https://w1/RSTS/Login";
logout_uri = "https://w1/RSTS/Login?wa=wsignout1.0";

windowWidth = 720;
windowHeight = 1024;

[DataSource.Kind="IdentityManager", Publish="IdentityManager.Publish"]
shared IdentityManager.Contents = (#"Application Server url" as text, Table as text) =>
    let
        _url = Diagnostics.LogValue("Application Server url", #"Application Server url"),
        _table = Diagnostics.LogValue("Get entities for", Table),
        finaleURL = _url & _table,

        source = Json.Document(Web.Contents(finaleURL))
    in
        source;

IdentityManager = [
    TestConnection = (dataSourcePath) => { "IdentityManager.Contents", dataSourcePath },

    Authentication = [
        OAuth = [
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
        ]
    ],

    Label = Extension.LoadString("DataSourceLabel")
];

StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "code", parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token);

Logout = (token) => logout_uri;

TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = "authorization_code",
            redirect_uri = redirect_uri,
            client_id = client_id
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_uri, [
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
    Beta = true,
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
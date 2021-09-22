// This file contains your Data Connector logic
section IdentityManager;

[DataSource.Kind="IdentityManager", Publish="IdentityManager.Publish"]
shared IdentityManager.Contents = (optional message as text) =>
    let
        _message = if (message <> null) then message else "(no message)",
        a = "Hello from Identity Manager: " & _message
    in
        a;

// Data Source Kind description
IdentityManager = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Implicit = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
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

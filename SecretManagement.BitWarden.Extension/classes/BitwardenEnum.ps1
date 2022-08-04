# SEE: https://bitwarden.com/help/article/cli/#enums

# Two-step Login Methods
# Used to specify which Two-step Login method to use when logging in
enum BitwardenMfaMethod {
    Authenticator   = 0
    Email           = 1
    Yubikey         = 2
}

# Item Types
# Used with the create command to specify a Vault item type
enum BitwardenItemType {
    Undefined       = 0
    Login           = 1
    SecureNote      = 2
    Card            = 3
    Identity        = 4
}

# Login URI Match Types
# Used with the create and edit commands to specify URI match detection behavior
enum BitwardenUriMatchType {
    Domain          = 0
    Host            = 1
    StartsWith      = 2
    Exact           = 3
    Regex           = 4
    Never           = 5
}

# Field Types
# Used with the create and edit commands to configure custom fields
enum BitwardenFieldType {
    Text            = 0
    Hidden          = 1
    Boolean         = 2
}

# Organization User Types
# Indicates a user's type
enum BitwardenOrganizationUserType {
    Owner           = 0
    Admin           = 1
    User            = 2
    Manager         = 3
}

# Organization User Statuses
# Indicates a user's status within the Organization
enum BitwardenOrganizationUserStatus {
    Invited         = 0
    Accepted        = 1
    Confirmed       = 2
}
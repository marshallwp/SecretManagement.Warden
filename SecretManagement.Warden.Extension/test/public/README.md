# Missing Tests
Tests for the following functions are not included as I have been unable to determine a way to invoke them in isolation from the `Microsoft.PowerShell.SecretManagement` module. The main issue is that they seem to be tied to Registered Vaults, and I have not been able to find a way to mock those.  Registering vaults just before running doesn't work either.

- Unlock-SecretVault
- Unregister-SecretVault

# List of countries for Active Directory and Office 365

## CountryCode ISO-3166
In Active Directory, when the country is set with a Microsoft MMC tool (ADUC - Active Directory Users and Computers, ADAC - Active Directory Administrative Center), all the country attributes (*c, co, countryCode*) are set.

But if the country is set manually or programmatically (LDAP, PowerShell, C/C++, C#, Java, etc.), the attributes *c, co, countryCode* must be filled according to the ISO-3166 norm.

If is also true if your Active Directory is synchronized to Azure AD/Office 365.

This repository provide a CSV file with all the countries and the corresponding *c, co, countryCode attributes*. This CSV can be used in your application/script.

## preferredLanguage and MailboxRegionalConfiguration
The *preferredLanguage* attribute is used:
* in AzureAD/Office 365 if the user has a 'cloud identity'
* in Active Directory if the user is synchronized to Azure AD/Office 365

It can also be used to set the Language in the *Set-MailboxRegionalConfiguration Language 'xx-XX'*

## Authors
* **Bastien PEREZ - ITPro-Tips.com**

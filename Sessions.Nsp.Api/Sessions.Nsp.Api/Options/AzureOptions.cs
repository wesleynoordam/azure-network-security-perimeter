namespace Sessions.Nsp.Api.Options;

public class AzureOptions
{
    public const string Section = "Azure";

    public required string KeyVaultUri { get; set; }
    public required string BlobContainerUri { get; set; }
    public required string BlobContainerName { get; set; }
}

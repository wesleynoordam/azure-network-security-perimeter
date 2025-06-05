using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Sessions.Nsp.Api.Options;

namespace Sessions.Nsp.Api.Controllers;

[ApiController]
[Route("[controller]")]
public class BackendController(IOptions<AzureOptions> azureConfig) : ControllerBase
{
    private readonly IOptions<AzureOptions> _azureConfig = azureConfig;

    [HttpGet("keyvault/secret", Name = "GetKeyVaultSecret")]
    public async Task<string> GetSecret()
    {
        try
        {
            var client = new SecretClient(new Uri(_azureConfig.Value.KeyVaultUri), new DefaultAzureCredential());
            var res = await client.GetSecretAsync("verysecret");

            return res.Value.Value;
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }

    [HttpGet("storageaccount/blob", Name = "GetStorageAccountBlob")]
    public async Task<string> GetBlob()
    {
        try
        {
            var blobServiceClient = new Azure.Storage.Blobs.BlobServiceClient(
            new Uri(_azureConfig.Value.BlobContainerUri),
            new DefaultAzureCredential());

            var containerClient = blobServiceClient.GetBlobContainerClient(_azureConfig.Value.BlobContainerName);
            var blobClient = containerClient.GetBlobClient("SomeBlob.txt");

            var downloadInfo = await blobClient.DownloadAsync();
            using var reader = new StreamReader(downloadInfo.Value.Content);

            return await reader.ReadToEndAsync();
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }
}

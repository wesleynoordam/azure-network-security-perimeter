using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Sessions.Vnet.Api.Controllers;

[ApiController]
[Route("[controller]")]
public class BackendController(IConfiguration configuration) : ControllerBase
{
    private readonly IConfiguration _configuration = configuration;

    [HttpGet("sql/connection", Name = "GetKeyVaultSecret")]
    public async Task<string> TestConnection()
    {
        try
        {
            var connstring = _configuration.GetConnectionString("sqlServer");

            using var connection = new SqlConnection(connstring);

            await connection.OpenAsync();
            
            return connection.State == System.Data.ConnectionState.Open
                ? "Connection successful"
                : "Connection failed";
        }
        catch (Exception ex)
        {
            return ex.Message;
        }
    }
}

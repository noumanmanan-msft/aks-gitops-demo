using Microsoft.AspNetCore.Mvc;

// Testing the improved retry logic workflow
namespace AspNetDemo.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class HelloController : ControllerBase
    {
        [HttpGet]
        public string Get() => "Hello World from ASP.NET on Windows Container using ArgoCD!";
    }
}

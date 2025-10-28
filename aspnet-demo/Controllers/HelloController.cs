using Microsoft.AspNetCore.Mvc;

namespace AspNetDemo.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class HelloController : ControllerBase
    {
        [HttpGet]
        public string Get() => "Hello World from ASP.NET on Windows Container!";
    }
}

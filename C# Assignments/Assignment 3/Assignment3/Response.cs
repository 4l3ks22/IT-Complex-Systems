namespace Assignment3;

public class Response
{
    public string Status { get; set; }
    public string? Body { get; set; }

    public Response(string status, string? body = null)
    {
        Status = status;
        Body = body;
    }
}
namespace Assignment3;

public class Response
{
    public string Status { get; set; }
    public string Body { get; set; }

    public Response(string Status, string? Body = null)
    {
        Status = Status;
        Body = Body;
    }
}
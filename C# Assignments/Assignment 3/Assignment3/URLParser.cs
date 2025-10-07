using System;

namespace Assignment3
{
    public class UrlParser
    {
        // Properties that describe the parsed URL
        public string Path { get; private set; } = string.Empty; // to initialize it with 0 characters
        public string Id { get; private set; }
        public bool HasId { get; private set; }

        // Main function that does the parsing
        public bool ParseUrl(string url)
        {
            // Validate that the input URL is not null or empty
            if (string.IsNullOrWhiteSpace(url))
                return false;

            // Normalize the URL by trimming whitespace
            url = url.Trim();

            // Split the URL into segments by '/'
            // Example: "/api/categories/5" => ["api", "categories", "5"]
            var parts = url.Split('/', StringSplitOptions.RemoveEmptyEntries);

            // There must be at least one part after /api
            if (parts.Length < 2)
                return false;

            // Build the base path (example: /api/categories)
            Path = $"/{parts[0]}/{parts[1]}";

            // If there’s a third segment, that’s the ID
            if (parts.Length > 2)
            {
                Id = parts[2];
                HasId = true;
            }
            else
            {
                Id = null;
                HasId = false;
            }

            return true; // Parsing succeeded
        }
    }
}
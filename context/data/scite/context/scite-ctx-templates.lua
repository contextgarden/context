-- this is just an example

return {
    xml = {
        {
            name     = "bold",
            nature   = "inline",
            template = "<b>?</b>",
        },
        {
            name     = "emphasized",
            nature   = "inline",
            template = "<em>?</em>",
        },
        {
            name     = "inline",
            nature   = "inline",
            template = "<m>?</m>",
        },
        {
            name     = "display",
            nature   = "display",
            template = "<math>?</math>",
        },
        {
            name     = "itemize",
            nature   = "display",
            template = "<itemize>\n    <item>?</item>\n    <item>?</item>\n    <item>?</item>\n</itemize>",
        },
    },
}

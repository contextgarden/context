local info = {
    version   = 1.001,
    comment   = "scintilla lpeg lexer for sql",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local P, R, S = lpeg.P, lpeg.R, lpeg.S

local lexer       = require("scite-context-lexer")
local context     = lexer.context
local patterns    = context.patterns

local token       = lexer.token
local exact_match = lexer.exact_match

local sqllexer    = lexer.new("sql","scite-context-lexer-sql")
local whitespace  = sqllexer.whitespace

-- ANSI SQL 92 | 99 | 2003

local keywords_standard = {
    "absolute", "action", "add", "after", "all", "allocate", "alter", "and", "any",
    "are", "array", "as", "asc", "asensitive", "assertion", "asymmetric", "at",
    "atomic", "authorization", "avg", "before", "begin", "between", "bigint",
    "binary", "bit", "bit_length", "blob", "boolean", "both", "breadth", "by",
    "call", "called", "cascade", "cascaded", "case", "cast", "catalog", "char",
    "char_length", "character", "character_length", "check", "clob", "close",
    "coalesce", "collate", "collation", "column", "commit", "condition", "connect",
    "connection", "constraint", "constraints", "constructor", "contains", "continue",
    "convert", "corresponding", "count", "create", "cross", "cube", "current",
    "current_date", "current_default_transform_group", "current_path",
    "current_role", "current_time", "current_timestamp",
    "current_transform_group_for_type", "current_user", "cursor", "cycle", "data",
    "date", "day", "deallocate", "dec", "decimal", "declare", "default",
    "deferrable", "deferred", "delete", "depth", "deref", "desc", "describe",
    "descriptor", "deterministic", "diagnostics", "disconnect", "distinct", "do",
    "domain", "double", "drop", "dynamic", "each", "element", "else", "elseif",
    "end", "equals", "escape", "except", "exception", "exec", "execute", "exists",
    "exit", "external", "extract", "false", "fetch", "filter", "first", "float",
    "for", "foreign", "found", "free", "from", "full", "function", "general", "get",
    "global", "go", "goto", "grant", "group", "grouping", "handler", "having",
    "hold", "hour", "identity", "if", "immediate", "in", "indicator", "initially",
    "inner", "inout", "input", "insensitive", "insert", "int", "integer",
    "intersect", "interval", "into", "is", "isolation", "iterate", "join", "key",
    "language", "large", "last", "lateral", "leading", "leave", "left", "level",
    "like", "local", "localtime", "localtimestamp", "locator", "loop", "lower",
    "map", "match", "max", "member", "merge", "method", "min", "minute", "modifies",
    "module", "month", "multiset", "names", "national", "natural", "nchar", "nclob",
    "new", "next", "no", "none", "not", "null", "nullif", "numeric", "object",
    "octet_length", "of", "old", "on", "only", "open", "option", "or", "order",
    "ordinality", "out", "outer", "output", "over", "overlaps", "pad", "parameter",
    "partial", "partition", "path", "position", "precision", "prepare", "preserve",
    "primary", "prior", "privileges", "procedure", "public", "range", "read",
    "reads", "real", "recursive", "ref", "references", "referencing", "relative",
    "release", "repeat", "resignal", "restrict", "result", "return", "returns",
    "revoke", "right", "role", "rollback", "rollup", "routine", "row", "rows",
    "savepoint", "schema", "scope", "scroll", "search", "second", "section",
    "select", "sensitive", "session", "session_user", "set", "sets", "signal",
    "similar", "size", "smallint", "some", "space", "specific", "specifictype",
    "sql", "sqlcode", "sqlerror", "sqlexception", "sqlstate", "sqlwarning", "start",
    "state", "static", "submultiset", "substring", "sum", "symmetric", "system",
    "system_user", "table", "tablesample", "temporary", "then", "time", "timestamp",
    "timezone_hour", "timezone_minute", "to", "trailing", "transaction", "translate",
    "translation", "treat", "trigger", "trim", "true", "under", "undo", "union",
    "unique", "unknown", "unnest", "until", "update", "upper", "usage", "user",
    "using", "value", "values", "varchar", "varying", "view", "when", "whenever",
    "where", "while", "window", "with", "within", "without", "work", "write", "year",
    "zone",
}

-- The dialects list is taken from drupal.org with standard subtracted.
--
-- MySQL 3.23.x | 4.x | 5.x
-- PostGreSQL 8.1
-- MS SQL Server 2000
-- MS ODBC
-- Oracle 10.2

local keywords_dialects = {
    "a", "abort", "abs", "access", "ada", "admin", "aggregate", "alias", "also",
    "always", "analyse", "analyze", "assignment", "attribute", "attributes", "audit",
    "auto_increment", "avg_row_length", "backup", "backward", "bernoulli", "bitvar",
    "bool", "break", "browse", "bulk", "c", "cache", "cardinality", "catalog_name",
    "ceil", "ceiling", "chain", "change", "character_set_catalog",
    "character_set_name", "character_set_schema", "characteristics", "characters",
    "checked", "checkpoint", "checksum", "class", "class_origin", "cluster",
    "clustered", "cobol", "collation_catalog", "collation_name", "collation_schema",
    "collect", "column_name", "columns", "command_function", "command_function_code",
    "comment", "committed", "completion", "compress", "compute", "condition_number",
    "connection_name", "constraint_catalog", "constraint_name", "constraint_schema",
    "containstable", "conversion", "copy", "corr", "covar_pop", "covar_samp",
    "createdb", "createrole", "createuser", "csv", "cume_dist", "cursor_name",
    "database", "databases", "datetime", "datetime_interval_code",
    "datetime_interval_precision", "day_hour", "day_microsecond", "day_minute",
    "day_second", "dayofmonth", "dayofweek", "dayofyear", "dbcc", "defaults",
    "defined", "definer", "degree", "delay_key_write", "delayed", "delimiter",
    "delimiters", "dense_rank", "deny", "derived", "destroy", "destructor",
    "dictionary", "disable", "disk", "dispatch", "distinctrow", "distributed", "div",
    "dual", "dummy", "dump", "dynamic_function", "dynamic_function_code", "enable",
    "enclosed", "encoding", "encrypted", "end-exec", "enum", "errlvl", "escaped",
    "every", "exclude", "excluding", "exclusive", "existing", "exp", "explain",
    "fields", "file", "fillfactor", "final", "float4", "float8", "floor", "flush",
    "following", "force", "fortran", "forward", "freetext", "freetexttable",
    "freeze", "fulltext", "fusion", "g", "generated", "granted", "grants",
    "greatest", "header", "heap", "hierarchy", "high_priority", "holdlock", "host",
    "hosts", "hour_microsecond", "hour_minute", "hour_second", "identified",
    "identity_insert", "identitycol", "ignore", "ilike", "immutable",
    "implementation", "implicit", "include", "including", "increment", "index",
    "infile", "infix", "inherit", "inherits", "initial", "initialize", "insert_id",
    "instance", "instantiable", "instead", "int1", "int2", "int3", "int4", "int8",
    "intersection", "invoker", "isam", "isnull", "k", "key_member", "key_type",
    "keys", "kill", "lancompiler", "last_insert_id", "least", "length", "less",
    "limit", "lineno", "lines", "listen", "ln", "load", "location", "lock", "login",
    "logs", "long", "longblob", "longtext", "low_priority", "m", "matched",
    "max_rows", "maxextents", "maxvalue", "mediumblob", "mediumint", "mediumtext",
    "message_length", "message_octet_length", "message_text", "middleint",
    "min_rows", "minus", "minute_microsecond", "minute_second", "minvalue",
    "mlslabel", "mod", "mode", "modify", "monthname", "more", "move", "mumps",
    "myisam", "name", "nesting", "no_write_to_binlog", "noaudit", "nocheck",
    "nocompress", "nocreatedb", "nocreaterole", "nocreateuser", "noinherit",
    "nologin", "nonclustered", "normalize", "normalized", "nosuperuser", "nothing",
    "notify", "notnull", "nowait", "nullable", "nulls", "number", "octets", "off",
    "offline", "offset", "offsets", "oids", "online", "opendatasource", "openquery",
    "openrowset", "openxml", "operation", "operator", "optimize", "optionally",
    "options", "ordering", "others", "outfile", "overlay", "overriding", "owner",
    "pack_keys", "parameter_mode", "parameter_name", "parameter_ordinal_position",
    "parameter_specific_catalog", "parameter_specific_name",
    "parameter_specific_schema", "parameters", "pascal", "password", "pctfree",
    "percent", "percent_rank", "percentile_cont", "percentile_disc", "placing",
    "plan", "pli", "postfix", "power", "preceding", "prefix", "preorder", "prepared",
    "print", "proc", "procedural", "process", "processlist", "purge", "quote",
    "raid0", "raiserror", "rank", "raw", "readtext", "recheck", "reconfigure",
    "regexp", "regr_avgx", "regr_avgy", "regr_count", "regr_intercept", "regr_r2",
    "regr_slope", "regr_sxx", "regr_sxy", "regr_syy", "reindex", "reload", "rename",
    "repeatable", "replace", "replication", "require", "reset", "resource",
    "restart", "restore", "returned_cardinality", "returned_length",
    "returned_octet_length", "returned_sqlstate", "rlike", "routine_catalog",
    "routine_name", "routine_schema", "row_count", "row_number", "rowcount",
    "rowguidcol", "rowid", "rownum", "rule", "save", "scale", "schema_name",
    "schemas", "scope_catalog", "scope_name", "scope_schema", "second_microsecond",
    "security", "self", "separator", "sequence", "serializable", "server_name",
    "setof", "setuser", "share", "show", "shutdown", "simple", "soname", "source",
    "spatial", "specific_name", "sql_big_result", "sql_big_selects",
    "sql_big_tables", "sql_calc_found_rows", "sql_log_off", "sql_log_update",
    "sql_low_priority_updates", "sql_select_limit", "sql_small_result",
    "sql_warnings", "sqlca", "sqrt", "ssl", "stable", "starting", "statement",
    "statistics", "status", "stddev_pop", "stddev_samp", "stdin", "stdout",
    "storage", "straight_join", "strict", "string", "structure", "style",
    "subclass_origin", "sublist", "successful", "superuser", "synonym", "sysdate",
    "sysid", "table_name", "tables", "tablespace", "temp", "template", "terminate",
    "terminated", "text", "textsize", "than", "ties", "tinyblob", "tinyint",
    "tinytext", "toast", "top", "top_level_count", "tran", "transaction_active",
    "transactions_committed", "transactions_rolled_back", "transform", "transforms",
    "trigger_catalog", "trigger_name", "trigger_schema", "truncate", "trusted",
    "tsequal", "type", "uescape", "uid", "unbounded", "uncommitted", "unencrypted",
    "unlisten", "unlock", "unnamed", "unsigned", "updatetext", "use",
    "user_defined_type_catalog", "user_defined_type_code", "user_defined_type_name",
    "user_defined_type_schema", "utc_date", "utc_time", "utc_timestamp", "vacuum",
    "valid", "validate", "validator", "var_pop", "var_samp", "varbinary", "varchar2",
    "varcharacter", "variable", "variables", "verbose", "volatile", "waitfor",
    "width_bucket", "writetext", "x509", "xor", "year_month", "zerofill",
}

local space         = patterns.space -- S(" \n\r\t\f\v")
local any           = patterns.any
local restofline    = patterns.restofline
local startofline   = patterns.startofline

local squote        = P("'")
local dquote        = P('"')
local bquote        = P('`')
local escaped       = P("\\") * P(1)

local begincomment  = P("/*")
local endcomment    = P("*/")

local decimal       = patterns.decimal
local float         = patterns.float
local integer       = P("-")^-1 * decimal

local spacing       = token(whitespace, space^1)
local rest          = token("default", any)

local shortcomment  = token("comment", (P("#") + P("--")) * restofline^0)
local longcomment   = token("comment", begincomment * (1-endcomment)^0 * endcomment^-1)

local p_validword   = R("AZ","az","__") * R("AZ","az","__","09")^0
local identifier    = token("default",p_validword)

local shortstring   = token("quote",  dquote) -- can be shared
                    * token("string", (escaped + (1-dquote))^0)
                    * token("quote",  dquote)
                    + token("quote",  squote)
                    * token("string", (escaped + (1-squote))^0)
                    * token("quote",  squote)
                    + token("quote",  bquote)
                    * token("string", (escaped + (1-bquote))^0)
                    * token("quote",  bquote)

local p_keywords_s  = exact_match(keywords_standard,nil,true)
local p_keywords_d  = exact_match(keywords_dialects,nil,true)
local keyword_s     = token("keyword", p_keywords_s)
local keyword_d     = token("command", p_keywords_d)

local number        = token("number", float + integer)
local operator      = token("special", S("+-*/%^!=<>;:{}[]().&|?~"))

sqllexer._tokenstyles = context.styleset

sqllexer._foldpattern = P("/*") + P("*/") + S("{}") -- separate entry else interference

sqllexer._foldsymbols = {
    _patterns = {
        "/%*",
        "%*/",
    },
    ["comment"] = {
        ["/*"] =  1,
        ["*/"] = -1,
    }
}

sqllexer._rules = {
    { "whitespace",   spacing      },
    { "keyword-s",    keyword_s    },
    { "keyword-d",    keyword_d    },
    { "identifier",   identifier   },
    { "string",       shortstring  },
    { "longcomment",  longcomment  },
    { "shortcomment", shortcomment },
    { "number",       number       },
    { "operator",     operator     },
    { "rest",         rest         },
}

return sqllexer

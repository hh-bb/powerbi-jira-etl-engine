// ==========================================
// 🇬🇧 ETL ENGINE FOR JIRA TICKETS
// 🇪🇸 MOTOR ETL PARA TICKETS DE JIRA
// File: sql/power_query_etl.m
// Query 1: "Tickets" (Fact Table & Cascading Logic)
// ==========================================

let
    // EN: 🔒 DATA SANITIZATION: URL masked for security purposes
    // ES: 🔒 SANITIZACIÓN: URL enmascarada por seguridad
    Source = GoogleSheets.Contents("https://docs.google.com/spreadsheets/d/[SPREADSHEET_ID]/edit?gid=0#gid=0"),
    Tickets_Table = Source{[name="Tickets",ItemKind="Table"]}[Data],
    
    #"Renamed Columns" = Table.RenameColumns(Tickets_Table,{{"Column1", "Tipo de Incidencia"}, {"Column2", "Clave"}, {"Column3", "Resumen"}, {"Column4", "Persona asignada"}, {"Column5", "Informador"}, {"Column6", "Prioridad"}, {"Column7", "Estado"}, {"Column8", "Resolución"}, {"Column9", "Creada"}, {"Column10", "Actualizada"}, {"Column11", "Fecha de vencimiento"}, {"Column12", "Request Type"}, {"Column13", "# of Assets"}, {"Column14", "Bannerflow"}, {"Column15", "Brand (STUD)"}, {"Column16", "Brand Form"}, {"Column17", "Estado de la entrega"}, {"Column18", "Objetivo ACQ"}, {"Column19", "Objetivo CRM"}}),
    #"Removed Top Rows" = Table.Skip(#"Renamed Columns",1),
    
    // EN: Locale-specific type casting for accurate date parsing
    // ES: Transformación de tipos con configuración regional para fechas exactas
    #"Changed Type with Locale" = Table.TransformColumnTypes(#"Removed Top Rows", {{"Creada", type text}}, "es-AR"),
    #"Changed Type with Locale 1" = Table.TransformColumnTypes(#"Changed Type with Locale", {{"Actualizada", type datetime}}, "es-AR"),
    #"Changed Type with Locale 2" = Table.TransformColumnTypes(#"Changed Type with Locale 1", {{"Creada", type datetime}}, "es-AR"),
    #"Changed Type with Locale 3" = Table.TransformColumnTypes(#"Changed Type with Locale 2", {{"Fecha de vencimiento", type date}}, "es-AR"),
    #"Changed Type with Locale 4" = Table.TransformColumnTypes(#"Changed Type with Locale 3", {{"Actualizada", type text}}, "es-AR"),
    #"Changed Type with Locale 5" = Table.TransformColumnTypes(#"Changed Type with Locale 4", {{"Fecha de vencimiento", type text}}, "es-AR"),
    
    #"Renamed Columns 1" = Table.RenameColumns(#"Changed Type with Locale 5",{{"Column20", "SubDepartments CRM"}, {"Column21", "Vertical"}, {"Column22", "Tipo de pieza CRM"}, {"Column23", "Tipo de pieza Medios"}, {"Column24", "Tipo de pieza Perfo"}, {"Column25", "Tipo de Pieza Product"}, {"Column26", "Tipo de pieza SM"}, {"Column27", "Tipo de Pieza Sponsorship"}, {"Column28", "Tipo de pieza [Casino Sports]"}, {"Column29", "Tipo de pieza [Sports]"}, {"Column30", "Formato Medios"}, {"Column31", "Formato Perfo"}, {"Column32", "Formato SM"}}),
    #"Changed Type with Locale 6" = Table.TransformColumnTypes(#"Renamed Columns 1", {{"Fecha de vencimiento", type date}}, "es-AR"),
    #"Changed Type with Locale 7" = Table.TransformColumnTypes(#"Changed Type with Locale 6", {{"Actualizada", type datetime}}, "es-AR"),
    #"Changed Type with Locale 8" = Table.TransformColumnTypes(#"Changed Type with Locale 7", {{"Creada", type date}}, "es-AR"),
    #"Changed Type with Locale 9" = Table.TransformColumnTypes(#"Changed Type with Locale 8", {{"Actualizada", type date}}, "es-AR"),
    
    #"Renamed Columns 2" = Table.RenameColumns(#"Changed Type with Locale 9",{{"Tipo de pieza [Casino Sports]", "Tipo de pieza Casino Sports"}, {"Tipo de pieza [Sports]", "Tipo de pieza Sports"}}),
    #"Renamed Columns 3" = Table.RenameColumns(#"Renamed Columns 2",{{"Column33", "Tipo de Pieza"}, {"Column34", "SubDepartments ACQ"}, {"Column35", "SubDepartments Product"}, {"Column36", "Subdeparment  [CRM] Vacío"}}),
    #"Reordered Columns" = Table.ReorderColumns(#"Renamed Columns 3",{"Tipo de Incidencia", "Clave", "Resumen", "Persona asignada", "Informador", "Prioridad", "Estado", "Resolución", "Creada", "Actualizada", "Fecha de vencimiento", "Request Type", "# of Assets", "Bannerflow", "Brand (STUD)", "Brand Form", "Estado de la entrega", "Objetivo ACQ", "Objetivo CRM", "SubDepartments CRM", "SubDepartments ACQ", "SubDepartments Product", "Vertical", "Tipo de pieza CRM", "Tipo de pieza Medios", "Tipo de pieza Perfo", "Tipo de Pieza Product", "Tipo de pieza SM", "Tipo de Pieza Sponsorship", "Tipo de pieza Casino Sports", "Tipo de pieza Sports", "Tipo de Pieza", "Formato Medios", "Formato Perfo", "Formato SM", "Subdeparment  [CRM] Vacío"}),
    
    #"Filtered Rows" = Table.SelectRows(#"Reordered Columns", each true),
    #"Removed Blank Rows" = Table.SelectRows(#"Filtered Rows", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
    #"Renamed Columns 4" = Table.RenameColumns(#"Removed Blank Rows",{{"Column37", "Department Form Generic"}}),
    
    // EN: Temporary cleaning of 'Product' for strict text evaluation (removes CHAR 160)
    // ES: Limpieza temporal de 'Product' para evaluación estricta (elimina CHAR 160)
    #"Cleaned Product SubDept" = Table.AddColumn(#"Renamed Columns 4", "CleanProd", each if [SubDepartments Product] = null then "" else Text.Trim(Text.Replace([SubDepartments Product], Character.FromNumber(160), ""))),
    
    #"Added Custom Form Logic" = Table.AddColumn(#"Cleaned Product SubDept", "Forms", each 
    // 1. EN: Force 'Brand&Content' strictly to Generic | ES: Forzar 'Brand&Content' estrictamente a Generic
    if [CleanProd] = "Brand&Content" or [CleanProd] = "BRAND & CONTENT" then "Form Generic"
    
    // 2. EN: Cascading Business Rules | ES: Reglas de Negocio en Cascada
    else if [SubDepartments CRM] <> null and [SubDepartments CRM] <> "" then "Form CRM"
    else if ([SubDepartments Product] <> null and [SubDepartments Product] <> "") 
         or ([Tipo de Pieza Product] <> null and [Tipo de Pieza Product] <> "") then "Form Product"
    else if ([SubDepartments ACQ] <> null and [SubDepartments ACQ] <> "") 
         or ([Tipo de pieza CRM] <> null and [Tipo de pieza CRM] <> "") 
         or ([Tipo de pieza Medios] <> null and [Tipo de pieza Medios] <> "") 
         or ([Tipo de pieza Perfo] <> null and [Tipo de pieza Perfo] <> "") 
         or ([Tipo de pieza SM] <> null and [Tipo de pieza SM] <> "")
         or ([Department Form Generic] = "Medios" or [Department Form Generic] = "Social media" or [Department Form Generic] = "Sponsorship") then "Form ACQ"
    else if ([Department Form Generic] <> null and [Department Form Generic] <> "") 
         or ([Tipo de Pieza] <> null and [Tipo de Pieza] <> "") then "Form Generic"
         
    // 3. EN: Reporter Fallback Logic (Data Sanitized) | ES: Lógica de Rescate por Informador (Sanitizado)
    else if [Informador] = "Felipe I." or [Informador] = "Franco L." or [Informador] = "Santiago N." or [Informador] = "Valentina M." or [Informador] = "Lara F." or [Informador] = "Leon D." then "Form CRM"
    else if [Informador] = "Agustin L." or [Informador] = "Anabel R." or [Informador] = "Ariadna R." or [Informador] = "Javier O." or [Informador] = "Tomas F." or [Informador] = "Camila A." or [Informador] = "Lucas Z." then "Form Product"
    else if [Informador] = "Alejandro L." or [Informador] = "Javier G." or [Informador] = "Maria C." or [Informador] = "Maximiliano P." or [Informador] = "Ramiro P." or [Informador] = "Francisco F." or [Informador] = "Juan V." or [Informador] = "Maria B." or [Informador] = "Lucila R." or [Informador] = "Paula G." or [Informador] = "Giuliano G." or [Informador] = "Pedro F." then "Form Generic"
    else if [Informador] = "Diego T." or [Informador] = "Lucila V." or [Informador] = "Luisina B." or [Informador] = "Nathalia V." or [Informador] = "Nicolas J." or [Informador] = "Nicolas S." or [Informador] = "Tobias G." or [Informador] = "Ulises M." or [Informador] = "Ana B." or [Informador] = "Elias R." or [Informador] = "Marco B." or [Informador] = "Ignacio R." then "Form ACQ" 
    else null),
    
    // EN: Cleanup and formatting transformations | ES: Transformaciones de limpieza y formato
    #"Removed Temp Column" = Table.RemoveColumns(#"Added Custom Form Logic",{"CleanProd"}),
    #"Duplicated Column" = Table.DuplicateColumn(#"Removed Temp Column", "Department Form Generic", "Department Form Generic - Copia"),
    #"Trimmed Brand Form" = Table.TransformColumns(#"Duplicated Column", {{"Brand Form", each Text.Trim(Text.Replace(if _ = null then "" else _, Character.FromNumber(160), "")), type text}}),
    #"Assets Changed to Int" = Table.TransformColumnTypes(#"Trimmed Brand Form", {{"# of Assets", Int64.Type}})
in
    #"Assets Changed to Int"


// ==========================================
// Query 2: "Categories" (Bridge Table & Sanitization)
// ==========================================
let
    Source = Tickets,
    #"Removed Other Columns" = Table.SelectColumns(Source,{"Clave", "Forms", "SubDepartments CRM", "SubDepartments ACQ", "SubDepartments Product", "Tipo de Pieza Product", "Tipo de Pieza"}),
    #"Filtered Rows" = Table.SelectRows(#"Removed Other Columns", each true),
    #"Removed Duplicates" = Table.Distinct(#"Filtered Rows", {"Clave"}),
    
    // EN: Left Outer Join to fetch attributes | ES: Left Outer Join para traer atributos
    #"Merged Queries" = Table.NestedJoin(#"Removed Duplicates", {"Clave"}, Tickets, {"Clave"}, "Tickets", JoinKind.LeftOuter),
    #"Expanded Tickets" = Table.ExpandTableColumn(#"Merged Queries", "Tickets", {"Tipo de pieza CRM", "Tipo de pieza Medios", "Tipo de pieza Perfo", "Tipo de Pieza Product", "Tipo de pieza SM", "Tipo de Pieza Sponsorship", "Tipo de pieza Casino Sports", "Tipo de pieza Sports", "Tipo de Pieza", "Formato Medios", "Formato Perfo", "Formato SM", "Department Form Generic", "Informador"}, {"Tickets.Tipo de pieza CRM", "Tickets.Tipo de pieza Medios", "Tickets.Tipo de pieza Perfo", "Tickets.Tipo de Pieza Product", "Tickets.Tipo de pieza SM", "Tickets.Tipo de Pieza Sponsorship", "Tickets.Tipo de pieza Casino Sports", "Tickets.Tipo de pieza Sports", "Tickets.Tipo de Pieza", "Tickets.Formato Medios", "Tickets.Formato Perfo", "Tickets.Formato SM", "Department Form Generic", "Informador"}),
    #"Removed Columns" = Table.RemoveColumns(#"Expanded Tickets",{"Tickets.Tipo de Pieza Product"}),
    #"Renamed Columns 1" = Table.RenameColumns(#"Removed Columns",{{"Tipo de Pieza", "ACQ.SocialMedia.Tipo de Pieza"}, {"Tickets.Tipo de pieza CRM", "CRM.Tipo de pieza"}, {"Tickets.Tipo de pieza Medios", "ACQ.Tipo de pieza Medios"}, {"Tickets.Tipo de pieza Perfo", "ACQ.Perfo.Tipo de pieza"}, {"Tickets.Tipo de pieza SM", "ACQ.SocialMedia.Tipo de pieza 2"}, {"Tickets.Tipo de Pieza Sponsorship", "ACQ.Sponsorship.Tipo de Pieza"}, {"Tickets.Formato Medios", "ACQ.Formato Medios"}, {"Tickets.Formato Perfo", "ACQ.Perfo.Formato Perfo"}, {"Tickets.Formato SM", "ACQ.Formato SM"}, {"Forms", "Form"}}),
    #"Removed Blank Rows" = Table.SelectRows(#"Renamed Columns 1", each not List.IsEmpty(List.RemoveMatchingItems(Record.FieldValues(_), {"", null}))),
    
    #"Added Custom Subdept" = Table.AddColumn(#"Removed Blank Rows", "Subdepartments Totales", each 
        let
            // EN: Master function to wipe invisible web characters | ES: Función maestra para limpiar caracteres invisibles
            CleanField = (campo) => if campo = null then "" else Text.Trim(Text.Replace(campo, Character.FromNumber(160), "")),
            
            CleanDept = CleanField([Department Form Generic]),
            CleanAcq  = CleanField([SubDepartments ACQ]),
            CleanProd = CleanField([SubDepartments Product]),
            CleanCrm  = CleanField([SubDepartments CRM]),
            
            // EN: Normalize 'Brand' subdepartments | ES: Normalizar subdepartamentos 'Brand'
            NormalizedProd = 
                if CleanProd = "Brand" or CleanProd = "Brand/Institucional" or CleanProd = "BRAND / INSTITUCIONAL" then "Institucional"
                else CleanProd,
            
            FinalResult = 
                if [Form] = "Form Generic" then 
                    (if CleanProd = "Brand&Content" or CleanProd = "BRAND & CONTENT" then "Brand&Content"
                     else if CleanDept <> "" then CleanDept 
                     else "Generic")
                     
                else if [Form] = "Form CRM" then 
                    (if CleanCrm <> "" then CleanCrm else "Vacío")
                    
                else if [Form] = "Form Product" then 
                    // (Data Sanitized: Pseudonyms applied)
                    (if NormalizedProd <> "" then NormalizedProd 
                     else if [Informador] = "Lucas Z." then "Sports" 
                     else "Vacío")
                     
                else if [Form] = "Form ACQ" then 
                    // (Data Sanitized: Pseudonyms applied)
                    (if CleanAcq <> "" then CleanAcq 
                     else if [Informador] = "Elias R." or [Informador] = "Marco B." then "Performance" 
                     else if [Informador] = "Ignacio R." then "Social Media" 
                     else "Vacío")
                else null
        in
            FinalResult
    ),
    #"Renamed Columns 2" = Table.RenameColumns(#"Added Custom Subdept",{{"Department Form Generic", "Column37"}})
in
    #"Renamed Columns 2"

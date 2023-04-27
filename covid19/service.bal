import ballerina/http;

// Definição do registro 
public type CovidEntry record {|
    readonly string iso_code;
    string country;
    decimal cases;
    decimal deaths;
    decimal recovered;
    decimal active;
|};

// Registro de erro
// Denotar que um tipo é um subtipo de outro
// Nesse caso, ConflictingIsoCodesError é um subtipo de http:Conflict.
public type ConflictingIsoCodesError record {|
    *http:Conflict;
    ErrorMsg body;
|};

// Registro de erro
// corpo da resposta é do tipo ErrorMsg
public type ErrorMsg record {|
    string errmsg;
|};

// Registro de erro
public type InvalidIsoCodeError record {|
    *http:NotFound;
    ErrorMsg body;
|};

# As tabelas Ballerina são usadas para armazenar dados. 
# Cada entrada na tabela é representada por um registro Ballerina.
public final table<CovidEntry> key(iso_code) covidTable = table [
    {iso_code: "AFG", country: "Afghanistan", cases: 159303, deaths: 7386, recovered: 146084, active: 5833},
    {iso_code: "SL", country: "Sri Lanka", cases: 598536, deaths: 15243, recovered: 568637, active: 14656},
    {iso_code: "US", country: "USA", cases: 69808350, deaths: 880976, recovered: 43892277, active: 25035097}
];

# Ambos os endpoints têm um segmento de URL comum.
# O serviço está associado a um http:Listener, que é a abstração Ballerina que lida com detalhes no nível 
# da rede, como host, porta, SSL etc.
# Primeiro endpoint para obter dados
service /covid/status on new http:Listener(9000) {
    // primeiro recurso para obter dados
    // métodos de recursos podem ter acessadores
    // o acessador é definido como get, o que significa que apenas GET solicitações HTTP podem atingir esse recurso
    // Ballerina serializa automaticamente os registros como JSON e os envia pela rede.
    resource function get countries() returns CovidEntry[] {
        return covidTable.toArray();
    }

    // Segundo recurso para adicionar dados
    // Para aceitar toda a carga útil ou enviar um erro
    // Argumento de recurso chamado covidEntries anotado com @http:Payload. 
    // CovideEntry[] e ConflictingIsoCodesError são valores de retorno.
    resource function post countries(@http:Payload CovidEntry[] covidEntries) 
                                returns CovidEntry[]|ConflictingIsoCodesError {
                                    
        string[] conflictingISOs = from CovidEntry covidEntry in covidEntries
            where covidTable.hasKey(covidEntry.iso_code)
            select covidEntry.iso_code;

        if conflictingISOs.length() > 0 {
            return {
                body: {
                    errmsg: string:'join(" ", "Codigos ISO conflitantes:", ...conflictingISOs)
                }
            };
        } else {
            covidEntries.forEach(covdiEntry => covidTable.add(covdiEntry));
            return covidEntries;
        }
    }

    // Segundo endpoint
    // Pesquisa pelo codigo ISO
    resource function get countries/[string iso_code]() returns CovidEntry|InvalidIsoCodeError {
    CovidEntry? covidEntry = covidTable[iso_code];
    if covidEntry is () {
        return {
            body: {
                errmsg: string `Codigo ISO invalido: ${iso_code}`
            }
        };
    }
    return covidEntry;
    }
}
unit uClienteVarejo_LeonardoVM;

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Forms, Vcl.Controls, Vcl.Graphics, Vcl.Dialogs,
  Data.DB, FireDAC.Comp.Client, uDtmGeral;

type
  TClientes = class
    private
      FCliCodigo  : Integer;
      FNome       : String;
      FCpf        : string;
    public
      property CliCodigo : Integer read FCliCodigo write FCliCodigo;
      property Nome      : String  read FNome      write FNome;
      property Cpf       : String  read FCpf       write FCpf;
  end;

  TCarros = class
    private
      FCarCodigo : Integer;
      FModelo    : String;
      FAnoLancto : Integer;
    public
      property CarCodigo  : Integer read FCarCodigo write FCarCodigo;
      property Modelo     : String  read FModelo    write FModelo;
      property AnoLancto  : Integer read FAnoLancto write FAnoLancto;
  end;

  TVendas = class
    private
      FVendaCodigo    : Integer;
      FVenCodCliente  : Integer;
      FVenCodCarro    : Integer;
      FDataVenda      : TDate;
    public
      property VendaCodigo    : Integer read FVendaCodigo   write FVendaCodigo;
      property VenCodCliente  : Integer read FVenCodCliente write FVenCodCliente;
      property VenCodCarro    : Integer read FVenCodCarro   write FVenCodCarro;
      property DataVenda      : TDate   read FDataVenda     write FDataVenda;
  end;


  TfrmClienteVarejo = class(TForm)

    procedure FormCreate(Sender: TObject);
    private
    procedure InserirClientes;
    procedure InserirCarros;
    procedure InserirVendas;
    procedure InserirDadosBD(Insercao : String);
    procedure ExcluirOutrasVendas;
    procedure CriarTabelas;
    function  ExecutarSql(Consulta,Campo : string) : Variant;

end;

var
  frmClienteVarejo: TfrmClienteVarejo;

Const
{             ---=== Criação de tabelas ===---             }

    SQL_Cria_Clientes = ' CREATE TABLE clientes (                        ' +
                        '   Cli_Codigo INT PRIMARY KEY,                  ' +
                        '   Cli_Nome   VARCHAR(100) NOT NULL,            ' +
                        '   Cli_Cpf    VARCHAR(11) NOT NULL              ' +
                        ' )                                              ';

    SQL_Cria_Carros = ' CREATE TABLE carros (                           ' +
                      '   Car_Codigo     INT PRIMARY KEY,               ' +
                      '   Car_Modelo     VARCHAR(50) NOT NULL,          ' +
                      '   Car_Ano_Lancto INT NOT NULL                   ' +
                      ' )                                               ';

    SQL_Cria_Vendas = ' CREATE TABLE vendas (                                          ' +
                      '   Ven_Codigo      INT PRIMARY KEY,                             ' +
                      '   Ven_Cod_Cliente INT NOT NULL REFERENCES clientes(Cli_Codigo),' +
                      '   Ven_Cod_Carro   INT NOT NULL REFERENCES carros(Car_Codigo),  ' +
                      '   Ven_Data        DATE NOT NULL                                ' +
                      ' )                                                              ';

{             ---=== Queries de consulta ===---             }

//  Quantidade de vendas do carro Marea
    SQL_Vendas_Marea = '   SELECT COUNT(*) AS Qtd_Vendas_Marea               '+
                       '     FROM vendas V                                   '+
                       '     JOIN carros C ON C.Car_Codigo = V.Ven_Cod_Carro '+
                       '    WHERE C.Car_Modelo = '+quotedstr('Marea')+'      ';

//  Quantidade de vendas do carro Uno por cliente
    SQL_Vendas_Uno =   '   SELECT V.Ven_Cod_Cliente,COUNT(*) AS Qtd_Vendas_Uno  '+
                       '     FROM vendas V                                      '+
                       '     JOIN carros C ON C.Car_Codigo = V.Ven_Cod_Carro    '+
                       '    WHERE C.Car_Modelo = '+quotedstr('Uno')+'           '+
                       ' GROUP BY v.Ven_Cod_Cliente                             ';

//  Quantidade de clientes que nao efetuaram venda
    SQL_Clientes_Sem_Venda = '   SELECT COUNT(*) AS Qtd_clientes_sem_venda                        '+
                             '     FROM clientes Cli                                              '+
                             '    WHERE NOT EXISTS (                                              '+
                             '   SELECT 1 FROM vendas V WHERE V.Ven_Cod_Cliente = Cli.Cli_Codigo  '+
                             '                     )                                              ';

{  Clientes sorteados Filtrando 15 primeiros por data_venda,
                                com CPF inicial de digito 0,
                                que compraram carros com ano_lancto = 2021
                                e não compraram dois Mareas                 }
    SQL_Sorteio_Clientes = '   SELECT Cli.Cli_Codigo, Cli.Cli_Nome                    '+
                           '     FROM clientes Cli                                    '+
                           '     JOIN vendas V ON V.Ven_Cod_Cliente = Cli.Cli_Codigo  '+
                           '     JOIN carros C ON C.Car_Codigo = V.Ven_Cod_Carro      '+
                           '    WHERE Cli.Cli_Cpf LIKE '+quotedstr('0%')+'            '+
                           '      AND C.Car_Ano_Lancto = 2021                         '+
                           '      AND Cli.Cli_Codigo NOT IN (                         '+
                           '                                                          '+
                           '    SELECT VN.Ven_Cod_Cliente                             '+
                           '      FROM vendas VN                                      '+
                           '      JOIN carros CN ON CN.Car_Codigo = VN.Ven_Cod_Carro  '+
                           '     WHERE CN.Car_Modelo = '+quotedstr('Marea')+'         '+
                           '     GROUP BY VN.Ven_Cod_Cliente                          '+
                           '    HAVING COUNT(*) >= 2                                  '+
                           '                                )                         '+
                           '     ORDER BY V.Ven_Data                                  '+
                           '     LIMIT 15                                             ';

//    Exclusao de vendas que nao pertencem aos clientes sorteados
    SQL_Exclusao_Outras_Vendas = '   DELETE FROM vendas V                                         '+
                                 '     WHERE NOT EXISTS  (                                        '+
                                 '                                                                '+
                                 '     SELECT 1 FROM clientes Cli                                 '+
                                 '       JOIN vendas VNE ON VNE.Ven_Cod_Cliente = Cli.Cli_Codigo  '+
                                 '       JOIN carros CNE ON CNE.Car_Codigo = VNE.Ven_Cod_Carro    '+
                                 '    WHERE Cli.Cli_Cpf LIKE '+quotedstr('0%')+'                  '+
                                 '      AND CNE.Car_Ano_Lancto = 2021                             '+
                                 '      AND V.Ven_Cod_Cliente = Cli.Cli_Codigo                    '+
                                 '      AND NOT EXISTS (                                          '+
                                 '                                                                '+
                                 '    SELECT 1 FROM vendas VNI                                    '+
                                 '      JOIN carros CNI ON CNI.Car_Codigo = VNI.Ven_Cod_Carro     '+
                                 '     WHERE VNI.Ven_Cod_Cliente = Cli.Cli_Codigo                 '+
                                 '       AND CNI.Car_Modelo = '+quotedstr('Marea')+'              '+
                                 '     GROUP BY VNI.Ven_Cod_Cliente                               '+
                                 '    HAVING COUNT(*) >= 2                                        '+
                                 '                                )                               '+
                                 '                       )                                        ';

end;

implementation

{$R *.dfm}

procedure TfrmClienteVarejo.FormCreate(Sender: TObject);
var
  VQtdMarea, VQtdSemVenda: Variant;
begin
{   para executar a consulta SQL_Vendas_Uno e SQL_Sorteio_Clientes
    bastaria montar a estrutura de retorno conforme demanda especifica  }

    CriarTabelas;

    InserirClientes;
    InserirCarros;
    InserirVendas;

    VQtdMarea    := ExecutarSql(SQL_Vendas_Marea,'Qtd_Vendas_Marea');
    VQtdSemVenda := ExecutarSql(SQL_Clientes_Sem_Venda,'Qtd_clientes_sem_venda');

    ExcluirOutrasVendas;
end;

procedure TfrmClienteVarejo.InserirClientes;
var
  LCliente  : TClientes;
  I         : Integer;
begin
    for I := 1 to 5 do
    begin
        LCliente := TClientes.Create;
        try
          LCliente.CliCodigo  := I;
          LCliente.Nome       := 'Cliente ' + IntToStr(I);
          LCliente.Cpf        := '0' + IntToStr(1000000000 + I);

          InserirDadosBD(Format('INSERT INTO clientes (Cli_Codigo, Cli_Nome, Cli_Cpf) VALUES (%d, ''%s'', ''%s'')',
                              [LCliente.CliCodigo , LCliente.Nome, LCliente.Cpf])
          );
        finally
          LCliente.Free;
        end;
    end;
end;

procedure TfrmClienteVarejo.InserirCarros;
const
  Modelos: array[1..5] of string = ('Marea', 'Uno', 'Opala', 'Polo', 'Santana');
var
  LCarro  : TCarros;
  I       : Integer;
begin
    for I := 1 to 5 do
    begin
        LCarro := TCarros.Create;
        try
          LCarro.CarCodigo  := I;
          LCarro.Modelo     := Modelos[I];
          LCarro.AnoLancto  := 2021;

          InserirDadosBD(Format('INSERT INTO carros (Car_Codigo, Car_Modelo, Car_Ano_Lancto) VALUES (%d, ''%s'', %d)',
              [LCarro.CarCodigo , LCarro.Modelo, LCarro.AnoLancto])
          );
        finally
          LCarro.Free;
        end;
    end;
end;

procedure TfrmClienteVarejo.InserirVendas;
var
  LVenda: TVendas;
  I: Integer;
begin
    for I := 1 to 5 do
    begin
        LVenda := TVendas.Create;
        try
          LVenda.VendaCodigo    := I;
          LVenda.VenCodCliente  := I;
          LVenda.VenCodCarro    := I;
          LVenda.DataVenda      := Date;

          InserirDadosBD(
            Format('INSERT INTO vendas (Ven_Codigo, Ven_Cod_Cliente, Ven_Cod_Carro, Ven_Data) VALUES (%d, %d, %d, ''%s'')',
                   [LVenda.VendaCodigo, LVenda.VenCodCliente, LVenda.VenCodCarro, DateToStr(LVenda.DataVenda)])
          );
        finally
          LVenda.Free;
        end;
    end;
end;

function TfrmClienteVarejo.ExecutarSql(Consulta, Campo : string) : Variant;
begin
    dtmGeral.FdQryGeral.Active := False;
    dtmGeral.FdQryGeral.SQL.Clear;
    dtmGeral.FdQryGeral.SQL.Add(Consulta);
    dtmGeral.FdQryGeral.Active := True;

    if not dtmGeral.FdQryGeral.IsEmpty then
    Result := dtmGeral.FdQryGeral.FieldByName(Campo).Value;
end;

procedure TfrmClienteVarejo.InserirDadosBD(Insercao : String);
begin
    if not dtmGeral.FDConnection.Connected then
      dtmGeral.FDConnection.Connected := True;

    dtmGeral.FDConnection.StartTransaction;
    try
      dtmGeral.FdQryGeral.Active := false;
      dtmGeral.FdQryGeral.SQL.Clear;
      dtmGeral.FdQryGeral.SQL.Text := Insercao;
      dtmGeral.FdQryGeral.ExecSQL;
      dtmGeral.FDConnection.Commit;
    except
      on E: Exception do
      begin
        dtmGeral.FDConnection.Rollback;
        raise Exception.Create('Erro ao executar SQL: ' + E.Message);
      end;
    end;
end;

procedure TfrmClienteVarejo.ExcluirOutrasVendas;
begin
    InserirDadosBD(SQL_Exclusao_Outras_Vendas);
end;

procedure TfrmClienteVarejo.CriarTabelas;
begin
    InserirDadosBD(SQL_Cria_Clientes);
    InserirDadosBD(SQL_Cria_Carros);
    InserirDadosBD(SQL_Cria_Vendas);
end;

end.
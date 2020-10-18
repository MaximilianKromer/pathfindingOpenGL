unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, OpenGLContext, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, GLU, GL, LCLType, GLUT;

type

  TEdge = record
    Node: Integer;
    Weight: Double;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    BGenerateGraph: TButton;
    BKeyboardControl: TButton;
    EInputSpace: TEdit;
    EInputNodes: TEdit;
    EInputEdges: TEdit;
    LDescriptionSpace: TLabel;
    LDescriptionNodes: TLabel;
    LDebug: TLabel;
    LDescriptionEdges: TLabel;
    OnApp: TApplicationProperties;
    OpenGLControl1: TOpenGLControl;
    procedure BKeyboardControlKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure BGenerateGraphClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OnAppIdle(Sender: TObject; var Done: Boolean);
    procedure OpenGLControl1Paint(Sender: TObject);
    procedure OpenGLControl1Resize(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

  TNode = class
  private
    FEdgeCount: Integer;
    FEdges: array of TEdge;
    FX: Double;
    FY: Double;
    FIndex: Integer;
    function GetEdge(index: Integer): TEdge;

  public
    constructor Create(index: Integer; x, y: Double);
    destructor Destroy; override;
    property x: Double read FX;
    property y: Double read FY;
    property EdgeCount: Integer read FEdgeCount;
    procedure AddEdge(nodeIndex: Integer; weight: Double = 0);
    procedure AddReturnEdge(nodeIndex: Integer; weight: Double = 0);
    property Edge [index: Integer]: TEdge read GetEdge;
    property Index: Integer read FIndex;
    class procedure AddClosestEdges(var node: TNode; quantity: Integer);
    class function CalcDistance(nodeA, nodeB: TNode): Double;
  end;



var
  Form1: TForm1;
  Nodes: Array of TNode;
  NodesCount, SelectedNode, StartNode, EndNode: Integer;

implementation

{$R *.lfm}

{ Reset Knoten Array um Renderfehler zu verhindern }
procedure Reset;
begin
  SelectedNode:= 0;
  StartNode:= 0;
  EndNode:= 0;
  NodesCount:= 0;
  SetLength(Nodes, NodesCount);
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  Randomize;
  Application.AddOnIdleHandler(@OnAppIdle);
  LDebug.Caption:='';

  Reset;
end;

{ Zufälligen Graphen generieren }
procedure TForm1.BGenerateGraphClick(Sender: TObject);
var
  i, j, tries, edgesNumber, space: Integer;
  x, y: Double;
  newNode: TNode;
  again: Boolean;
begin
  Reset;
  LDebug.Caption:='';
  NodesCount:=StrToInt(EInputNodes.Text);
  edgesNumber:=StrToInt(EInputEdges.Text);
  space:=StrToInt(EInputSpace.Text);

  SetLength(Nodes, NodesCount);

  // Knoten erstellen, mit gewissen Abstand
  Nodes[0]:= TNode.Create(0, (Random(191)-95)/100, (Random(191)-95)/100);

  i:=1;
  tries:=0;
  while i < NodesCount do
    begin
      Inc(tries);
      again:= False;
      x:= (Random(191)-95)/100;
      y:= (Random(191)-95)/100;
      newNode:= TNode.Create(i, x, y);

      for j:=0 to i - 1 do
        begin
          if TNode.CalcDistance(newNode, Nodes[j]) < space then again:= True;
        end;

      if tries > 1000000 then
        begin
          LDebug.Caption:='Fehler beim Generieren';
          Reset;
          Exit;
        end;

      if again <> True Then
        begin
          Nodes[i]:= newNode;
          tries:=0;
          Inc(i);
        end;
    end;

  // Kanten hinzufügen
  for i:=0 to NodesCount - 1 do
    begin
      TNode.AddClosestEdges(Nodes[i], edgesNumber);
    end;
end;


{ Tastatureingaben auswerten }
procedure TForm1.BKeyboardControlKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  Case Key of
    VK_RIGHT: Inc(SelectedNode);
    VK_LEFT: Dec(SelectedNode);
    VK_S: StartNode:=SelectedNode;
    VK_E: EndNode:=SelectedNode;
  end;
  if SelectedNode > NodesCount - 1 then SelectedNode:=0;
  if SelectedNode < 0 then SelectedNode:=NodesCount - 1;
  if Key <> VK_TAB then Key := 0;
end;

procedure TForm1.OnAppIdle(Sender: TObject; var Done: Boolean);
begin
  Done:=False;
  OpenGLControl1.Invalidate;
end;

procedure DrawText(x, y: Double; text: String);
var
  i: Integer;
  font: Pointer;
begin
  glColor3f(1, 1, 1);
  font:= GLUT_BITMAP_TIMES_ROMAN_10;
  glRasterPos2f(x, y);
  FOR i:= 1 TO Length(text) DO
    glutBitmapCharacter(font, ORD(text[i]));

end;

procedure DrawNode(node: TNode; r, g, b: Double);
begin
  glColor3f(r, g, b);
  glBegin(GL_POINTS);
    glVertex2f(node.x, node.y);
  glEnd;
  DrawText(node.x - 0.0125, node.y - 0.008, IntToStr(node.Index));
end;

procedure DrawEdges(node: TNode);
var
  i: Integer;
begin
  for i:=0 to node.EdgeCount - 1 do
    begin
      glVertex2f(node.x, node.y);
      glVertex2f(Nodes[node.Edge[i].Node].x, Nodes[node.Edge[i].Node].y);
    end;
end;

procedure TForm1.OpenGLControl1Paint(Sender: TObject);
var
  i: Integer;
begin
  glClearColor(0.4, 0.4, 1, 0);
  glClear(GL_COLOR_BUFFER_BIT OR GL_DEPTH_BUFFER_BIT);



  glEnable(GL_LINE_SMOOTH);
  glEnable(GL_POINT_SMOOTH);

  glBegin(GL_QUADS);

    // WHite Background
    glColor3f(0.98, 0.98, 0.98);
    glVertex2f(-1, 1);
    glVertex2f(-1, -1);
    glVertex2f(1, -1);
    glVertex2f(1, 1);
  glEnd;

  glPointSize(20);  
  glLineWidth(2);

  glBegin(GL_LINES);
    glColor3f(0.375, 0.4883, 0.5312);
    for i:=0 to NodesCount - 1 do
      DrawEdges(Nodes[i]);
  glEnd;


  for i:=0 to NodesCount - 1 do
    DrawNode(Nodes[i], 0.1484, 0.1953, 0.2187);

  if NodesCount > 0 then
    begin
      glColor3f(1, 1, 0);
      DrawNode(Nodes[SelectedNode], 0.8984, 0.3164, 0);
      glColor3f(0, 0.4, 0);
      DrawNode(Nodes[StartNode], 0.1992, 0.4101, 0.1172);
      glColor3f(0.5, 0, 0);
      DrawNode(Nodes[EndNode], 0.7148, 0.1094, 0.1094);
    end;


  sleep(30);

  // --- nicht löschen
  glFlush(); // Zeichnen
  OpenGLControl1.SwapBuffers; // Bildschirmausgabe aktualisieren
end;

procedure TForm1.OpenGLControl1Resize(Sender: TObject);
begin
  IF OpenGLControl1.Height <= 0 THEN Exit;
end;


{ TNode }

constructor TNode.Create(index: Integer; x, y: Double);
begin
  SetLength(FEdges, 0);
  FEdgeCount:=0;
  FX:=x;
  FY:=y;
  FIndex:=index;
end;

destructor TNode.Destroy;
begin
  SetLength(FEdges, 0); 
  FEdgeCount:=0;
end;

procedure TNode.AddEdge(nodeIndex: Integer; weight: Double = 0);
var
  i: Integer;
  exist: Boolean;
begin
  exist:= False;

  for i:=0 to FEdgeCount-1 do
    if FEdges[i].Node = nodeIndex then exist:= True;

  if exist = False then
    begin
      Inc(FEdgeCount);
      SetLength(FEdges, FEdgeCount);
      FEdges[FEdgeCount - 1].Node:= nodeIndex;
      FEdges[FEdgeCount - 1].Weight:= weight;
      Nodes[nodeIndex].AddReturnEdge(FIndex);
    end;
end;

procedure TNode.AddReturnEdge(nodeIndex: Integer; weight: Double = 0);
begin
  Inc(FEdgeCount);
  SetLength(FEdges, FEdgeCount);
  FEdges[FEdgeCount - 1].Node:= nodeIndex;
  FEdges[FEdgeCount - 1].Weight:= weight;
end;

function TNode.GetEdge(index: Integer): TEdge;
begin
  result:= FEdges[index];
end;

{
  Nodes nach Entfernung sortieren
  Edge zu den n nächsten erstellen
}
class procedure TNode.AddClosestEdges(var node: TNode; quantity: Integer);
var
  i, k: Integer;
  sorted: Array of TNode;
  temp: TNode;
begin
  SetLength(sorted, NodesCount);

  sorted[0]:= Nodes[0];
  for i:= 1 to NodesCount - 1 do
    begin
      sorted[i]:= Nodes[i];
      k:= i;
      while (k > 0) and (CalcDistance(node, sorted[k]) < CalcDistance(node, sorted[k-1])) do
        begin
          temp:= sorted[k-1];
          sorted[k-1]:= sorted[k];
          sorted[k]:= temp;
          Dec(k);
        end;
    end;

  for i:=1 to quantity do
    node.AddEdge(sorted[i].Index);
end;

{  Berechnet die Distanz zwischen zewi Knoten mit S. d. Pythagoras  }
class function TNode.CalcDistance(nodeA, nodeB: TNode): Double;
begin
  result:= sqrt(sqr(nodeA.x - nodeB.x) + sqr(nodeA.y - nodeB.y)) * 100;
end;

end.











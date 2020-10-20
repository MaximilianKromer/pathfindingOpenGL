unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, OpenGLContext, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, GLU, GL, LCLType, EpikTimer, GLUT;

type

  TEdge = record
    Node: Integer;
    Weight: Double;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    BCalcAlg2: TButton;
    BCalcAlg3: TButton;
    BGenerateGraph: TButton;
    BVisAlg1: TButton;
    BKeyboardControl: TButton;
    BCalcAlg1: TButton;
    BVisAlg2: TButton;
    BVisAlg3: TButton;
    EInputSpace: TEdit;
    EInputNodes: TEdit;
    EInputEdges: TEdit;
    ET: TEpikTimer;
    LDescriptionSpace: TLabel;
    LDescriptionNodes: TLabel;
    LDebug: TLabel;
    LDescriptionEdges: TLabel;
    LTimeAlg2: TLabel;
    LTimeAlg3: TLabel;
    LTitleAlg1: TLabel;
    LTitleAlg2: TLabel;
    LTimeAlg1: TLabel;
    LTitleAlg3: TLabel;
    OnApp: TApplicationProperties;
    OpenGLControl1: TOpenGLControl;
    procedure BCalcAlg1Click(Sender: TObject);
    procedure BKeyboardControlKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure BGenerateGraphClick(Sender: TObject);
    procedure BVisAlg1Click(Sender: TObject);
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
    FDistance: Double;
    FPreviousNode: Integer;
    FFinished: Boolean;
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
    property Distance: Double read FDistance write FDistance;
    property PreviousNode: Integer read FPreviousNode write FPreviousNode;
    property Finished: Boolean read FFinished write FFinished;
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

{ Graph Zurücksetzen als Vorbereitung für Algorithmus}
procedure ResetNodes;
VAR
  i: Integer;
begin
  for i:=0 to NodesCount - 1 do
    begin
      Nodes[i].Distance:= -1;
      Nodes[i].PreviousNode:= -1;
      Nodes[i].Finished:= False;
    end;
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

    { __________ Dijkstra __________ }
procedure TForm1.BCalcAlg1Click(Sender: TObject);
VAR
  finished: Boolean;
  i, u: Integer;
begin
  ResetNodes;
  ET.Clear;
  ET.Start;
  { Vorbereiten }
  finished:= False;
  Nodes[StartNode].Distance:= 0;

  { Hauptschleife }
  repeat
    // Knoten mit kleinster Distance finden
    u:= -1;
    FOR i:= 0 TO NodesCount - 1 DO
      begin
        IF (Nodes[i].Distance > -1) AND (Nodes[i].Finished = False) THEN
          IF (u = -1) OR (Nodes[i].Distance < Nodes[u].Distance) THEN
             u:= i;
      end;

    // Jede Kante zum neuen Knoten als Distanz setzen
    FOR i:= 0 TO Nodes[u].EdgeCount - 1 DO
      begin
        IF (Nodes[Nodes[u].GetEdge(i).Node].Distance = -1) OR (Nodes[Nodes[u].GetEdge(i).Node].Distance > (Nodes[u].Distance + Nodes[u].GetEdge(i).Weight)) THEN
          begin
            Nodes[Nodes[u].GetEdge(i).Node].Distance:= Nodes[u].Distance + Nodes[u].GetEdge(i).Weight;
            Nodes[Nodes[u].GetEdge(i).Node].PreviousNode:=u;
          end;
      end;

    Nodes[u].Finished:=True;

    // Abbruch bei gefundenem Ziel
    IF u = EndNode THEN
      finished:= True;

  until finished;
  ET.Stop;
  LTimeAlg1.Caption:= FloatToStr(ET.Elapsed*1000)  + 'ms';
end;

    { __________ Dijkstra - Vis __________ }
procedure TForm1.BVisAlg1Click(Sender: TObject);
VAR
  finished: Boolean;
  i, u: Integer;
begin
  ResetNodes;
  { Vorbereiten }
  finished:= False;
  Nodes[StartNode].Distance:= 0;

  { Hauptschleife }
  repeat
    Sleep(500);

    // Knoten mit kleinster Distance finden
    u:= -1;
    FOR i:= 0 TO NodesCount - 1 DO
      begin
        IF (Nodes[i].Distance > -1) AND (Nodes[i].Finished = False) THEN
          IF (u = -1) OR (Nodes[i].Distance < Nodes[u].Distance) THEN
             u:= i;
      end;

    SelectedNode:=u;
    OpenGLControl1Paint(OpenGLControl1);

    // Jede Kante zum neuen Knoten als Distanz setzen
    FOR i:= 0 TO Nodes[u].EdgeCount - 1 DO
      begin
        IF (Nodes[Nodes[u].GetEdge(i).Node].Distance = -1) OR (Nodes[Nodes[u].GetEdge(i).Node].Distance > (Nodes[u].Distance + Nodes[u].GetEdge(i).Weight)) THEN
          begin
            Nodes[Nodes[u].GetEdge(i).Node].Distance:= Nodes[u].Distance + Nodes[u].GetEdge(i).Weight;
            Nodes[Nodes[u].GetEdge(i).Node].PreviousNode:=u;
            Sleep(500);
          end;
      end;

    Nodes[u].Finished:=True;

    // Abbruch bei gefundenem Ziel
    IF u = EndNode THEN
      finished:= True;

  until finished;
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
  DrawText(node.x - 0.0125, node.y - 0.008, FloatToStr(node.Distance));
end;

procedure DrawEdges(node: TNode);
var
  i: Integer;
begin
  for i:=0 to node.EdgeCount - 1 do
    begin
      glBegin(GL_LINES);
        glColor3f(0.7383, 0.7383, 0.7383);
        glVertex2f(node.x, node.y);
        glVertex2f(Nodes[node.Edge[i].Node].x, Nodes[node.Edge[i].Node].y);
      glEnd;
    end;
end;

procedure DrawEdge(node1, node2: TNode; r, g, b: Double);
begin
  glBegin(GL_LINES);
    glColor3f(r, g, b);
    glVertex2f(node1.x, node1.y);
    glVertex2f(node2.x, node2.y);
  glEnd;
end;

procedure DrawShortestPath(node: TNode);
begin
  IF node.PreviousNode <> -1 THEN
    begin
      DrawEdge(node, Nodes[node.PreviousNode], 0.7734, 0.1562, 0.1652);
      DrawShortestPath(Nodes[node.PreviousNode]);
    end;
end;

{ ============ Paint Procedure ============ }
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

  // alle Kanten zeichnen
  for i:=0 to NodesCount - 1 do
    DrawEdges(Nodes[i]);

  // Kürzeste Kante zum Startpunkt zeichnen
  for i:=0 to NodesCount - 1 do
    IF Nodes[i].PreviousNode <> -1 THEN
      IF Nodes[i].Finished THEN
        DrawEdge(Nodes[i], Nodes[Nodes[i].PreviousNode], 0.0820, 0.3945, 0.7500)
      ELSE
        DrawEdge(Nodes[i], Nodes[Nodes[i].PreviousNode], 0.0117, 0.6601, 0.9531);

  // Kürzesten Weg von Start zu Ziel zeichnen
  if NodesCount > 0 then
     DrawShortestPath(Nodes[EndNode]);

  // Punkte zeichnen
  for i:=0 to NodesCount - 1 do
    DrawNode(Nodes[i], 0.1484, 0.1953, 0.2187);

  // Spezielle Punkte zeichnen
  if NodesCount > 0 then
    begin                                     
      // Ekndpunkt
      DrawNode(Nodes[EndNode], 0.7148, 0.1094, 0.1094);
      // Startpunkt
      DrawNode(Nodes[StartNode], 0.1992, 0.4101, 0.1172);
      // Ausgewählter Punkt
      DrawNode(Nodes[SelectedNode], 0.8984, 0.3164, 0);
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


{ ---------------- TNode ---------------- }

constructor TNode.Create(index: Integer; x, y: Double);
begin
  SetLength(FEdges, 0);
  FEdgeCount:=0;
  FX:=x;
  FY:=y;
  FIndex:=index;
  FDistance:= -1;
  FPreviousNode:= -1;
  FFinished:=False;
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
      // Setze weight auf Distanz
      IF weight = 0 THEN weight:= CalcDistance(Nodes[FIndex], Nodes[nodeIndex]);
      FEdges[FEdgeCount - 1].Weight:= weight;
      Nodes[nodeIndex].AddReturnEdge(FIndex, weight);
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











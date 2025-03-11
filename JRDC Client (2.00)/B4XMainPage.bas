B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
'#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=%PROJECT_NAME%.zip

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	Private lblTitle As B4XView
	Private lblBack As B4XView
	Private clvRecord As CustomListView
	Private btnEdit As B4XView
	Private btnDelete As B4XView
	Private btnNew As B4XView
	Private lblName As B4XView
	Private lblCategory As B4XView
	Private lblCode As B4XView
	Private lblPrice As B4XView
	Private indLoading As B4XLoadingIndicator
	Private PrefDialog1 As PreferencesDialog
	Private PrefDialog2 As PreferencesDialog
	Private PrefDialog3 As PreferencesDialog
	Dim Viewing As String
	Dim CategoryId As Long
	Dim Category() As Category
End Sub

Public Sub Initialize
'	B4XPages.GetManager.LogEvents = True
End Sub

Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	Root.LoadLayout("MainPage")
	B4XPages.SetTitle(Me, "JRDC Client")
	#if B4J
	CallSubDelayed3(Me, "SetScrollPaneBackgroundColor", clvRecord, xui.Color_Transparent)
	#End If
End Sub

Private Sub B4XPage_CloseRequest As ResumableSub
	If xui.IsB4A Then
		'back key in Android
		If PrefDialog1.BackKeyPressed Then Return False
		If PrefDialog2.BackKeyPressed Then Return False
		If PrefDialog3.BackKeyPressed Then Return False
	End If
	If Viewing = "Product" Then
		Viewing = "Category"
		lblTitle.Text = "Category"
		lblBack.Visible = False
		CreateDialog1
		CreateDialog2
		CreateDialog3
		GetCategories
		Return False
	End If
	Return True
End Sub

Private Sub B4XPage_Appear
	GetCategories
End Sub

Private Sub B4XPage_Resize(Width As Int, Height As Int)
	If PrefDialog1.IsInitialized And PrefDialog1.Dialog.Visible Then PrefDialog1.Dialog.Resize(Width, Height)
	If PrefDialog2.IsInitialized And PrefDialog2.Dialog.Visible Then PrefDialog2.Dialog.Resize(Width, Height)
	If PrefDialog3.IsInitialized And PrefDialog3.Dialog.Visible Then PrefDialog3.Dialog.Resize(Width, Height)
End Sub

'Don't miss the code in the Main module + manifest editor.
Private Sub IME_HeightChanged (NewHeight As Int, OldHeight As Int)
	PrefDialog1.KeyboardHeightChanged(NewHeight)
	PrefDialog2.KeyboardHeightChanged(NewHeight)
	PrefDialog3.KeyboardHeightChanged(NewHeight)
End Sub

#If B4J
Private Sub SetScrollPaneBackgroundColor(View As CustomListView, Color As Int)
	Dim SP As JavaObject = View.GetBase.GetView(0)
	Dim V As B4XView = SP
	V.Color = Color
	Dim V As B4XView = SP.RunMethod("lookup", Array(".viewport"))
	V.Color = Color
End Sub
#End If

Sub CreateRequest As DBRequestManager
	Dim req As DBRequestManager
	req.Initialize(Me, Main.rdcLink)
	Return req
End Sub

' Do not use cmd in B4i
' https://www.b4x.com/android/forum/threads/jrdc2-with-cmd-not-a-valid-identifier-error.102919/
Sub CreateCommand (Name As String, Parameters() As Object) As DBCommand
	Dim command As DBCommand
	command.Initialize
	command.Name = "SQL." & Name
	If Parameters <> Null Then command.Parameters = Parameters
	Return command
End Sub

#If B4J
Private Sub lblBack_MouseClicked (EventData As MouseEvent)
#Else
Private Sub lblBack_Click
#End If
	If Viewing = "Product" Then
		Viewing = "Category"
		lblTitle.Text = "Category"
		lblBack.Visible = False
		CreateDialog1
		CreateDialog2
		CreateDialog3
		GetCategories
	End If
End Sub

Private Sub btnReconnect_Click
	If Viewing = "Product" Then
		GetProducts
	Else
		GetCategories
	End If
End Sub

Private Sub btnNew_Click
	If Category.Length = 0 Then Return
	If Viewing = "Product" Then
		Dim ProductMap As Map = CreateMap("Product Code": "", "Category": GetCategoryName(CategoryId), "Product Name": "", "Product Price": "", "id": 0)
		ShowDialog2("Add", ProductMap)
	Else
		Dim CategoryMap As Map = CreateMap("Category Name": "", "id": 0)
		ShowDialog1("Add", CategoryMap)
	End If
End Sub

Private Sub btnEdit_Click
	Dim Index As Int = clvRecord.GetItemFromView(Sender)
	Dim lst As B4XView = clvRecord.GetPanel(Index)
	If Viewing = "Product" Then
		If CategoryId = 0 Then Return
		Dim ProductId As Long = clvRecord.GetValue(Index)
		Dim pnl As B4XView = lst.GetView(0)
		Dim v1 As B4XView = pnl.GetView(0)
		#if b4i
		Dim v2 As B4XView = pnl.GetView(1).GetView(0) ' using panel
		#else
		Dim v2 As B4XView = pnl.GetView(1)
		#End If
		Dim v3 As B4XView = pnl.GetView(2)
		Dim v4 As B4XView = pnl.GetView(3)
		Dim ProductMap As Map = CreateMap("Product Code": v1.Text, "Category": v2.Text, "Product Name": v3.Text, "Product Price": v4.Text.Replace(",", ""), "id": ProductId)
		ShowDialog2("Edit", ProductMap)
	Else
		CategoryId = clvRecord.GetValue(Index)
		Dim pnl As B4XView = lst.GetView(0)
		Dim v1 As B4XView = pnl.GetView(0)
		Dim CategoryMap As Map = CreateMap("Category Name": v1.Text, "id": CategoryId)
		ShowDialog1("Edit", CategoryMap)
	End If
End Sub

Private Sub btnDelete_Click
	Dim Index As Int = clvRecord.GetItemFromView(Sender)
	Dim Id As Long = clvRecord.GetValue(Index)
	Dim lst As B4XView = clvRecord.GetPanel(Index)
	Dim pnl As B4XView = lst.GetView(0)
	If Viewing = "Product" Then
		If CategoryId = 0 Then Return
		Dim v1 As B4XView = pnl.GetView(2)
	Else
		CategoryId = clvRecord.GetValue(Index)
		Dim v1 As B4XView = pnl.GetView(0)
	End If
	Dim M1 As Map
	M1.Initialize
	M1.Put("Item", v1.Text)
	ShowDialog3(M1, Id)
End Sub

Private Sub GetCategories
	Try
		indLoading.Show
		clvRecord.Clear
		Dim req As DBRequestManager = CreateRequest
		Dim com As DBCommand = CreateCommand("SELECT_ALL_CATEGORIES", Null)
		Wait For (req.ExecuteQuery(com, 0, Null)) JobDone (job As HttpJob)
		If job.Success Then
			req.HandleJobAsync(job, "req")
			Wait For (req) req_Result (res As DBResult)
			'req.PrintTable(res)
			
			Dim i As Int
			Dim Category(res.Rows.Size) As Category
			For Each row() As Object In res.Rows
				Category(i).Id = row(0)
				Category(i).Name = row(1)
				i = i + 1
			Next
			For i = 0 To Category.Length - 1
				clvRecord.Add(CreateCategoryItems(Category(i).Name, clvRecord.AsView.Width), Category(i).Id)
			Next
			Viewing = "Category"
			lblTitle.Text = "Category"
			lblBack.Visible = False
			CreateDialog1
			CreateDialog2
			CreateDialog3
		Else
			xui.MsgboxAsync(job.ErrorMessage, "Error")
		End If
	Catch
		xui.MsgboxAsync(LastException.Message, "Error")
	End Try
	job.Release
	indLoading.Hide
End Sub

Private Sub GetProducts
	Try
		indLoading.Show
		clvRecord.Clear
		Dim req As DBRequestManager = CreateRequest
		Dim com As DBCommand = CreateCommand("SELECT_PRODUCT_BY_CATEGORY_ID", Array As Object(CategoryId))
		Wait For (req.ExecuteQuery(com, 0, Null)) JobDone (job As HttpJob)
		If job.Success Then
			req.HandleJobAsync(job, "req")
			Wait For (req) req_Result (res As DBResult)
			'req.PrintTable(res)
			
			For Each row() As Object In res.Rows
				clvRecord.Add(CreateProductItems(row(2), GetCategoryName(row(1)), row(3), NumberFormat2(row(4), 1, 2, 2, True), clvRecord.AsView.Width), row(0))
			Next
			
			'If res.Rows.Size = 0 Then
			'	xui.MsgboxAsync("No Products Found", "Product")
			'End If
			
			Viewing = "Product"
			lblTitle.Text = GetCategoryName(CategoryId)
			lblBack.Visible = True
		Else
			xui.MsgboxAsync(job.ErrorMessage, "Error")
		End If
	Catch
		xui.MsgboxAsync(LastException.Message, "Error")
	End Try
	job.Release
	indLoading.Hide
End Sub

Private Sub GetCategoryName (Id As Long) As String
	Dim i As Long
	For i = 0 To Category.Length - 1
		If Category(i).Id = Id Then
			Return Category(i).Name
		End If
	Next
	Return ""
End Sub

Private Sub GetCategoryId (Name As String) As Long
	Dim i As Long
	For i = 0 To Category.Length - 1
		If Category(i).Name = Name Then
			Return Category(i).Id
		End If
	Next
	Return 0
End Sub

Private Sub clvRecord_ItemClick (Index As Int, Value As Object)
	If Viewing = "Category" Then
		CategoryId = Value
		GetProducts
	End If
End Sub

Private Sub CreateCategoryItems (Name As String, Width As Double) As B4XView
	Dim p As B4XView = xui.CreatePanel("")
	p.SetLayoutAnimated(0, 0, 0, Width, 90dip)
	p.LoadLayout("CategoryItem")
	lblName.Text = Name
	Return p
End Sub

Private Sub CreateProductItems (ProductCode As String, CategoryName As String, ProductName As String, ProductPrice As String, Width As Double) As B4XView
	Dim p As B4XView = xui.CreatePanel("")
	p.SetLayoutAnimated(0, 0, 0, Width, 180dip)
	p.LoadLayout("ProductItem")
	lblCode.Text = ProductCode
	lblCategory.Text = CategoryName
	lblName.Text = ProductName
	lblPrice.Text = ProductPrice
	Return p
End Sub

Private Sub CreateDialog1
	PrefDialog1.Initialize(Root, "Category", 300dip, 70dip)
	PrefDialog1.Dialog.OverlayColor = xui.Color_ARGB(128, 0, 10, 40)
	PrefDialog1.Dialog.TitleBarHeight = 50dip
	PrefDialog1.LoadFromJson(File.ReadString(File.DirAssets, "template_category.json"))
End Sub

Private Sub CreateDialog2
	Dim categories As List
	categories.Initialize
	For i = 0 To Category.Length - 1
		categories.Add(Category(i).Name)
	Next
	PrefDialog2.Initialize(Root, "Product", 300dip, 250dip)
	PrefDialog2.Dialog.OverlayColor = xui.Color_ARGB(128, 0, 10, 40)
	PrefDialog2.Dialog.TitleBarHeight = 50dip
	PrefDialog2.LoadFromJson(File.ReadString(File.DirAssets, "template_product.json"))
	PrefDialog2.SetOptions("Category", categories)
	PrefDialog2.SetEventsListener(Me, "PrefDialog2") '<-- must add to handle events.
End Sub

Private Sub CreateDialog3
	PrefDialog3.Initialize(Root, "Delete", 300dip, 70dip)
	PrefDialog3.Theme = PrefDialog3.THEME_LIGHT
	PrefDialog3.Dialog.OverlayColor = xui.Color_ARGB(128, 0, 10, 40)
	PrefDialog3.Dialog.TitleBarHeight = 50dip
	PrefDialog3.Dialog.TitleBarColor = xui.Color_RGB(220, 20, 60)
	PrefDialog3.AddSeparator("default")
End Sub

Private Sub ShowDialog1 (Action As String, Item As Map)
	If Action = "Add" Then
		PrefDialog1.Dialog.TitleBarColor = xui.Color_RGB(50, 205, 50)
	Else
		PrefDialog1.Dialog.TitleBarColor = xui.Color_RGB(65, 105, 225)
	End If
	PrefDialog1.Title = Action & " Category"
	Dim sf As Object = PrefDialog1.ShowDialog(Item, "OK", "CANCEL")
	#if B4A or B4i
	PrefDialog1.Dialog.Base.Top = 100dip ' Make it lower
	#Else
	'Dim sp As ScrollPane = PrefDialog1.CustomListView1.sv
	'sp.SetVScrollVisibility("NEVER")
	Sleep(0)
	PrefDialog1.CustomListView1.sv.Height = PrefDialog1.CustomListView1.sv.ScrollViewInnerPanel.Height + 10dip
	#End If
	' Fix Linux UI (Long Text Button)
	Dim btnCancel As B4XView = PrefDialog1.Dialog.GetButton(xui.DialogResponse_Cancel)
	btnCancel.Width = btnCancel.Width + 20dip
	btnCancel.Left = btnCancel.Left - 20dip
	btnCancel.TextColor = xui.Color_Red
	Dim btnOk As B4XView = PrefDialog1.Dialog.GetButton(xui.DialogResponse_Positive)
	btnOk.Left = btnOk.Left - 20dip
	Wait For (sf) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		If 0 = Item.Get("id") Then
			indLoading.Show
			Dim com As DBCommand = CreateCommand("INSERT_NEW_CATEGORY", Array As Object(Item.Get("Category Name")))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(com, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("New category created!", "Add")
				GetCategories
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Add")
			End If
		Else
			indLoading.Show
			Dim com As DBCommand = CreateCommand("UPDATE_CATEGORY_BY_ID", Array As Object(Item.Get("Category Name"), Item.Get("id")))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(com, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("Category updated!", "Edit")
				GetCategories
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Edit")
			End If
		End If
		job.Release
		indLoading.Hide
	End If
End Sub

Private Sub ShowDialog2 (Action As String, Item As Map)
	If Action = "Add" Then
		PrefDialog2.Dialog.TitleBarColor = xui.Color_RGB(50, 205, 50)
	Else
		PrefDialog2.Dialog.TitleBarColor = xui.Color_RGB(65, 105, 225)
	End If
	PrefDialog2.Title = Action & " Product"
	Dim sf As Object = PrefDialog2.ShowDialog(Item, "OK", "CANCEL")
	Sleep(0)
	PrefDialog2.CustomListView1.sv.Height = PrefDialog2.CustomListView1.sv.ScrollViewInnerPanel.Height + 10dip
	Wait For (sf) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		If 0 = Item.Get("id") Then
			indLoading.Show
			Dim NewCategoryId As Long = GetCategoryId(Item.Get("Category"))
			Dim com As DBCommand = CreateCommand("INSERT_NEW_PRODUCT", Array As Object(GetCategoryId(Item.Get("Category")), Item.Get("Product Code"), Item.Get("Product Name"), Item.Get("Product Price")))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(com, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("New product created!", "Add")
				CategoryId = NewCategoryId
				GetProducts
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Add")
			End If
		Else
			indLoading.Show
			Dim NewCategoryId As Long = GetCategoryId(Item.Get("Category"))
			Dim com As DBCommand = CreateCommand("UPDATE_PRODUCT_BY_ID", Array As Object(GetCategoryId(Item.Get("Category")), Item.Get("Product Code"), Item.Get("Product Name"), Item.Get("Product Price"), Item.Get("id")))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(com, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("Product updated!", "Edit")
				CategoryId = NewCategoryId
				GetProducts
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Edit")
			End If
		End If
		job.Release
		indLoading.Hide
	End If
End Sub

Private Sub PrefDialog2_BeforeDialogDisplayed (Template As Object)
	Try
		' Fix Linux UI (Long Text Button)
		Dim btnCancel As B4XView = PrefDialog2.Dialog.GetButton(xui.DialogResponse_Cancel)
		btnCancel.Width = btnCancel.Width + 20dip
		btnCancel.Left = btnCancel.Left - 20dip
		btnCancel.TextColor = xui.Color_Red
		Dim btnOk As B4XView = PrefDialog2.Dialog.GetButton(xui.DialogResponse_Positive)
		If btnOk.IsInitialized Then
			btnOk.Width = btnOk.Width + 20dip
			btnOk.Left = btnCancel.Left - btnOk.Width
		End If
	Catch
		Log(LastException)
	End Try
End Sub

Private Sub ShowDialog3 (Item As Map, Id As Long)
	PrefDialog3.Title = "Delete " & Viewing
	Dim sf As Object = PrefDialog3.ShowDialog(Item, "OK", "CANCEL")
	#if B4A or B4i
	PrefDialog3.Dialog.Base.Top = 100dip ' Make it lower
	#Else
	' Fix Linux UI (Long Text Button)
	'Dim sp As ScrollPane = PrefDialog3.CustomListView1.sv
	'sp.SetVScrollVisibility("NEVER")
	Sleep(0)
	PrefDialog3.CustomListView1.sv.Height = PrefDialog3.CustomListView1.sv.ScrollViewInnerPanel.Height + 10dip
	#End If
	Dim btnCancel As B4XView = PrefDialog3.Dialog.GetButton(xui.DialogResponse_Cancel)
	btnCancel.Width = btnCancel.Width + 20dip
	btnCancel.Left = btnCancel.Left - 20dip
	btnCancel.TextColor = xui.Color_Red
	Dim btnOk As B4XView = PrefDialog3.Dialog.GetButton(xui.DialogResponse_Positive)
	btnOk.Left = btnOk.Left - 20dip
	PrefDialog3.CustomListView1.GetPanel(0).GetView(0).Text = Item.Get("Item")
	#If B4i
	PrefDialog3.CustomListView1.GetPanel(0).GetView(0).TextSize = 16 ' Text too small in ios
	#Else
	PrefDialog3.CustomListView1.GetPanel(0).GetView(0).TextSize = 15 ' 14
	#End If
	PrefDialog3.CustomListView1.GetPanel(0).GetView(0).Color = xui.Color_Transparent
	PrefDialog3.CustomListView1.sv.ScrollViewInnerPanel.Color = xui.Color_Transparent
	Wait For (sf) Complete (Result As Int)
	If Result = xui.DialogResponse_Positive Then
		If Viewing = "Product" Then
			indLoading.Show
			Dim cmd1 As DBCommand = CreateCommand("DELETE_PRODUCT_BY_ID", Array As Object(Id))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(cmd1, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("Product deleted!", "Delete")
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Delete")
			End If
			job.Release
			indLoading.Hide
			GetProducts
		Else
			indLoading.Show
			Dim com As DBCommand = CreateCommand("DELETE_CATEGORY_BY_ID", Array As Object(Id))
			Dim job As HttpJob = CreateRequest.ExecuteCommand(com, Null)
			Wait For (job) JobDone (job As HttpJob)
			If job.Success Then
				xui.MsgboxAsync("Category deleted!", "Delete")
			Else
				xui.MsgboxAsync(job.ErrorMessage, "Delete")
			End If
			job.Release
			indLoading.Hide
			GetCategories
		End If
	End If
End Sub
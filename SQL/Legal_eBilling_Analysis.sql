/**
------------------------------------------------------------------------------------
PROJECT: eBilling & Legal Operations Analytics Portfolio
DESCRIPTION: End-to-end SQL script covering data cleaning, financial control, 
		     compliance tracking, timekeeper performance, and process velocity.
------------------------------------------------------------------------------------
**/

------------------------------------------------------------------------------------
-- SECTION 1: DATABASE SETUP & DATA TYPE STANDARDIZATION
------------------------------------------------------------------------------------

-- Creating and Select Database
Create Database eBilling_Portfolio_Project;
Use eBilling_Portfolio_Project;

-- Fetch first 100 rows of Invoices_Log
Select Top 100 * From Invoices_Log;

-- Fetch first 50 rows of Matters_Budgets
Select Top 50 * From Matters_Budgets;

-- Fetch first 50 rows of Timekeeper_Rates
Select Top 50 * From Timekeeper_Rates;

-- Standardize Invoices_Log Amount Columns to Decimal
Alter Table Invoices_Log Alter Column Invoice_Amount Decimal(18,2);
Alter Table Invoices_Log Alter Column Reduction_Amount Decimal(18,2);
Alter Table Invoices_Log Alter Column Appeal_Amount_Accepted Decimal(18,2);

-- Standardize Matters_Budgets Amount Columns to Decimal
Alter Table Matters_Budgets Alter Column Budget_Amount Decimal(18,2);
Alter Table Matters_Budgets Alter Column Accrual_Amount Decimal(18,2);

-- Standardize Timekeeper_Rates Rate Column to Decimal
Alter Table Timekeeper_Rates Alter Column Hourly_Rate Decimal(18,2);

------------------------------------------------------------------------------------
-- SECTION 2: DATA PREVIEW & FINANCIAL RECONCILIATION
------------------------------------------------------------------------------------

-- Preview core tables
Select Top 100 * From Invoices_Log;
Select Top 50 * From Matters_Budgets;
Select Top 50 * From Timekeeper_Rates;

Select
    Count(*) As Invoice_Count,
    Count(Distinct Invoice_ID) As Unique_Invoices,
    Sum(Invoice_Amount) As Total_Invoiced,
    Sum(Reduction_Amount) As Total_Reductions,
    Sum(Appeal_Amount_Accepted) As Total_Appeals
From Invoices_Log;

------------------------------------------------------------------------------------
-- SECTION 3: CORE ANALYTICAL & OPERATIONAL QUERIES
------------------------------------------------------------------------------------

-- 1. Unapproved Budgets
Select 
	I.Invoice_ID, I.Queue_Type, I.Vendor_Site, I.Invoice_Status,
	   M.Matter_Number, M.Client_Name, M.Practice_Area, M.Budget_Amount, M.Budget_Status
From Invoices_Log As I
Left join Matters_Budgets As M
On I.Matter_Number = M.Matter_Number
Where M.Budget_Status = 'Not Approved';

-- 2. Budget Variance Analysis (Using CTE & MAX to prevent join duplication)
With Budget_Analysis As (
Select I.Matter_Number,M.Practice_Area,M.Budget_Status,
	   Sum(I.Invoice_Amount) Total_Invoice_Amt,
	   Max(M.Budget_Amount) As Total_Budget_Amt,
	   Sum(I.Invoice_Amount) - Max(M.Budget_Amount) As Variance_Amount,
Case
When Sum(I.Invoice_Amount) > Max(M.Budget_Amount) Then 'Budget Overrun'
Else 'Under Budget'
End As Budget_Status_Flag
From Invoices_Log As I
Left join Matters_Budgets As M
On I.Matter_Number = M.Matter_Number
Group by I.Matter_Number,M.Practice_Area, M.Budget_Status
)
Select * From Budget_Analysis Where Budget_Status_Flag = 'Budget Overrun';

-- 3. Invoice Status Pipeline Breakdown
Select
	Invoice_Status, 
	Count(Distinct Invoice_ID) As Invoice_Count,
	Sum(Invoice_Amount) As Total_Amount
From Invoices_Log
Group By Invoice_Status
Order By Total_Amount Desc;

-- 4. Billing Reduction Analysis by Reason
Select 
	Reduction_Reason, 
	Sum(Reduction_Amount) As Total_Reduction_Amt
From Invoices_Log
Where Invoice_Status = 'Reduced'
Group By Reduction_Reason
Order By Total_Reduction_Amt Desc;

-- 5. Client Ranking by Gross Billing
With Client_Billing As (
    Select
        Client_Name,
        Sum(Invoice_Amount) As Total_Billing_Volume
    From Invoices_Log
    Group By Client_Name
)
Select
    Client_Name,
    Total_Billing_Volume,
    Dense_Rank() Over (Order By Total_Billing_Volume Desc) As Billing_Rank
From Client_Billing
Order By Billing_Rank, Client_Name;

-- 6. Rejected Invoice Value by Reason
Select 
	Rejection_Reason, Count(Distinct Invoice_ID) As Invoice_Count,
	   Sum(Invoice_Amount) Total_Amount
From Invoices_Log
Where Invoice_Status = 'Rejected'
Group By Rejection_Reason
Order By Total_Amount Desc;

-- 7. Monthly Billing Trends
Select
	Format(Invoice_Date, 'yyyy-MM') As Billing_Month,
	Count(Distinct Invoice_ID) As Total_Invoices,
	Sum(Invoice_Amount) As Total_Billing_Volume
From Invoices_Log
Group By Format(Invoice_Date, 'yyyy-MM')
Order By Billing_Month;

-- 8. Submission-to-Paid-Status Processing Time
Select
	Client_Name,Invoice_ID,Date_Submitted,
	Status_Date, Invoice_Status,
	DATEDIFF(Day, Date_Submitted, Status_Date) As Processing_Cycle_Days
From Invoices_Log
Where Invoice_Status = 'Paid'
Order By Processing_Cycle_Days Desc;

-- 9. Average Submission-to-Paid-Status Processing Time by Client
Select
	Client_Name,
	Cast(Avg(Cast(DATEDIFF(Day, Date_Submitted, Status_Date) As Decimal(18,2))) As Decimal (18,2)) As Processing_Cycle_Days
From Invoices_Log
Where Invoice_Status = 'Paid'
Group By Client_Name
Order By Processing_Cycle_Days Desc;

-- 10. High-Value Invoices Above $250,000
Select
    Invoice_ID, Matter_Number, Client_Name,
    Invoice_Amount, Invoice_Status
From Invoices_Log
Where Invoice_Amount > 250000
Order By Invoice_Amount Desc;
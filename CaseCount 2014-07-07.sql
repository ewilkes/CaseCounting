DECLARE @Start DATE = '07-01-2013'
DECLARE @End DATE = '7/31/2014'--'12-31-2013'
--DECLARE @Start DATE = '04-01-2014'
--DECLARE @End DATE = '04-30-2014'
DECLARE @OfficeCode TABLE
(
	Value VARCHAR(1000)
)
--INSERT INTO @OfficeCode VALUES ('BECTO')	--Bell County Office
--INSERT INTO @OfficeCode VALUES ('BLRTB')	--Bluegrass Region
--INSERT INTO @OfficeCode VALUES ('BOCTO')	--Boone County Office
--INSERT INTO @OfficeCode VALUES ('BOGTO')	--Bowling Green Office
INSERT INTO @OfficeCode VALUES ('BOYCT')	--Boyd County Office
--INSERT INTO @OfficeCode VALUES ('BUCTO')	--Bullitt County Office
--INSERT INTO @OfficeCode VALUES ('COLTO')	--Columbia Office
--INSERT INTO @OfficeCode VALUES ('COTOU')	--Covington Office
--INSERT INTO @OfficeCode VALUES ('CYTOU')	--Cynthiana Office
--INSERT INTO @OfficeCode VALUES ('DATOU')	--Danville Office
--INSERT INTO @OfficeCode VALUES ('DPANW')	--Newport Office
--INSERT INTO @OfficeCode VALUES ('ELITO')	--Elizabethtown Office
--INSERT INTO @OfficeCode VALUES ('FRATO')	--Frankfort Trial Office
--INSERT INTO @OfficeCode VALUES ('GLCTO')	--Glasgow Office
--INSERT INTO @OfficeCode VALUES ('HATOU')	--Harlan Office
--INSERT INTO @OfficeCode VALUES ('HAZTO')	--Hazard Office
--INSERT INTO @OfficeCode VALUES ('HENTO')	--Henderson Office
--INSERT INTO @OfficeCode VALUES ('HOPTO')	--Hopkinsville Office
--INSERT INTO @OfficeCode VALUES ('LAGTO')	--LaGrange Trial Office
--INSERT INTO @OfficeCode VALUES ('LELIS')	--Lexington Office - 2nd Floor
--INSERT INTO @OfficeCode VALUES ('LEXOF')	--Lexington Office
--INSERT INTO @OfficeCode VALUES ('LMOWS')	--Lexington Office - 6th & 7th Floors
--INSERT INTO @OfficeCode VALUES ('LONTO')	--London Office
--INSERT INTO @OfficeCode VALUES ('MADTO')	--Madisonville Office
--INSERT INTO @OfficeCode VALUES ('MAYTO')	--Maysville Office
--INSERT INTO @OfficeCode VALUES ('MORTO')	--Morehead Office
--INSERT INTO @OfficeCode VALUES ('MURTO')	--Murray Office
--INSERT INTO @OfficeCode VALUES ('OWTOF')	--Owensboro Office
--INSERT INTO @OfficeCode VALUES ('PADTO')	--Paducah Office
--INSERT INTO @OfficeCode VALUES ('PIKTO')	--Pikeville Office
--INSERT INTO @OfficeCode VALUES ('PRTOU')	--Prestonsburg Office
--INSERT INTO @OfficeCode VALUES ('RITRO')	--Richmond Office
--INSERT INTO @OfficeCode VALUES ('SOTOU')	--Somerset Office
--INSERT INTO @OfficeCode VALUES ('STANT')	--Stanton Office
;
--CTEs to cut down on unneccessary fields
WITH Case_CTE AS
(
	SELECT
		CaseID
		,CaseTypeCode
		,CaseTypeDesc
		,CaseStatusCode
		,CaseReceivedDt
		,CaseTitle
		,AgencyAddByCode
		,AgencyAddByDesc
	FROM
		jw50_Case
)
,CaseAgency_CTE AS
(
	SELECT
		CaseID
		,CaseAgencyNameID
		,CaseAgencyID
		,AgencyCode
		,CaseAgencyDesc
		,CaseAgencyMasterCode
		,CaseAgencyNumber
		,CaseAgencyAddDt
		,CaseAgencyLead
	FROM
		jw50_CaseAgency
)
,NameAttributes_CTE AS
(
	SELECT
		NameID
		,NameAttributeCode
		,NameAttributeCodeListCode
		,NameAttributeCodeListDesc
	FROM
		jw50_NameAttributes
)
,CaseInvPers_CTE AS
(
	SELECT
		CaseID
		,CaseInvPersNameID
		,CaseInvPersActive
		,CaseInvPersActiveDt
		,CaseInvPersInactiveDt
		,CaseAgencyID
		,CaseAgencyNameID
		,InvolveTypeCode
		,InvolveTypeDesc
		,InvolveTypeMasterCode
		,CaseInvPersFullName
		,CaseInvPersFullName2
		,CaseAgencyDesc
		,ForCaseInvPersNameID
	FROM
		jw50_CaseInvPers
)
--Other CTEs
,RuleOne_CTE AS
(
	SELECT		
		CASE
			WHEN COUNT(judge.InvolveTypeCode) = 1 THEN c.CaseReceivedDt
			WHEN COUNT(judge.InvolveTypeCode) > 1 THEN ISNULL(
																(
																	SELECT TOP 1 
																		judge1.CaseInvPersActiveDt
																	FROM
																		CaseInvPers_CTE AS judge1
																			CROSS APPLY
																		(
																			SELECT TOP 1
																				CaseID
																				,CaseAgencyID
																			FROM
																				CaseAgency_CTE
																			WHERE
																				CaseID = c.CaseID
																				AND CaseAgencyLead = 1
																				AND CaseAgencyMasterCode = 2
																		) AS ca
																	WHERE
																		judge1.CaseAgencyID = ca.CaseAgencyID
																		AND judge1.InvolveTypeCode = 'CIT03'
																	ORDER BY
																		judge1.CaseInvPersActiveDt ASC
																	),c.CaseReceivedDt
																)
		END AS RuleOneDt
		,c.CaseID
	FROM
		Case_CTE AS c
			CROSS APPLY--Changing to a CROSS APPLY might negate the need for a GROUP BY and potentially speed things up; needs testing since I don't have access to your server
		(
			SELECT
				CaseID
				,InvolveTypeCode
			FROM
				CaseInvPers_CTE
			WHERE
				CaseID = c.CaseID
				AND InvolveTypeMasterCode = 14
		) AS judge
	WHERE
		c.CaseTypeCode IN ('CT16','CTCE','CTDMV','CTFEL','CTJUV','CTJVA','CTMIS','CTOTH','CTPPR','CTREV','CTWRT') --Trial Court Cases
	GROUP BY
		judge.CaseID
		,c.CaseReceivedDt
		,c.CaseID
)
,OfficeList_CTE AS
(
	SELECT
		NumAttyOfficeTotal = SUM(NumAttyOffice) OVER (PARTITION BY Division) 
		,AgencyCode
	FROM
		(
			SELECT DISTINCT
				ca.CaseAgencyDesc
				,ca.AgencyCode
				,NumAttyOffice = CAST(ats.NameAttributeCodeListDesc AS INT) 
				,Division = na.NameAttributeCodeListCode 
			FROM
				CaseAgency_CTE AS ca 
					INNER JOIN
				NameAttributes_CTE AS na 
						ON na.NameID = ca.CaseAgencyNameID
						AND na.NameAttributeCodeListCode = 'TRIAL' 
					LEFT OUTER JOIN
				NameAttributes_CTE AS ats 
						ON ats.NameID = ca.CaseAgencyNameID
						AND ats.NameAttributeCode = 'ATTST' 
			WHERE
					--ca.AgencyCode IN (@OfficeCode)
					ca.AgencyCode IN (SELECT VALUE FROM @OfficeCode)
		) AS atstotal
)
,Main_CTE AS
(
	
	SELECT
		c.CaseID
		,c.CaseTypeCode
		,c.CaseTypeDesc
		,c.CaseStatusCode
		,Client = client.CaseInvPersFullName2
		,c.CaseTitle
		,Office = ISNULL(office.CaseAgencyDesc,c.AgencyAddByDesc) 
		,OfficeCode = ISNULL(office.AgencyCode,c.AgencyAddByCode) 
		,InvestigatorStaffing = CAST(inv.NameAttributeCodeListDesc AS INT) 
		,SupportStaffing = CAST(ss.NameAttributeCodeListDesc AS INT) 
		,ServiceType = ISNULL(saty.NameAttributeCodeListDesc,'N/A') 
		,Court = ISNULL(Court.CaseAgencyDesc,'No Court')
		,CourtID = Court.CaseAgencyID
		,Court.CaseAgencyNameID
		,CourtNum = Court.CaseAgencyNumber 
		,County = ISNULL(County.NameAttributeCodeListDesc,'No County') 
		,[Static] = 'Static'
		,NumAttyOffice = CAST(ats.NameAttributeCodeListDesc AS INT) 
	FROM
		Case_CTE AS c 
			LEFT JOIN
		CaseAgency_CTE AS office 
				ON office.CaseID = c.CaseID
			LEFT JOIN
		CaseAgency_CTE AS court 
				ON c.CaseID = court.CaseID	
				AND court.CaseAgencyMasterCode = 2 --Courts			 
			LEFT JOIN
		NameAttributes_CTE AS county
				ON county.NameID = court.CaseAgencyNameID
				AND county.NameAttributeCode = 'COUNT' 
			OUTER APPLY
		(
			SELECT TOP 1
				cip.CaseInvPersFullName2
			FROM
				CaseInvPers_CTE AS cip
			WHERE
				cip.CaseID = c.CaseID
				AND cip.InvolveTypeCode = 'CIT07'
		) AS client
			LEFT JOIN
		NameAttributes_CTE AS saty 
				ON saty.NameID = office.CaseAgencyNameID
				AND saty.NameAttributeCode = 'SATY' 
			LEFT JOIN
		NameAttributes_CTE AS inv 
				ON inv.NameID = office.CaseAgencyNameID
				AND inv.NameAttributeCode = 'INVST' 
			LEFT JOIN
		NameAttributes_CTE AS ss 
				ON ss.NameID = office.CaseAgencyNameID
				AND ss.NameAttributeCode = 'SSSTF'  --Active attorneys
			LEFT JOIN
		NameAttributes_CTE AS ats 
				ON ats.NameID = office.CaseAgencyNameID
				AND ats.NameAttributeCode = 'ATTST'
)
,CaseCountRules_CTE AS
(
	SELECT
		temp.CaseID
		,[Rule]
		,Heading
	FROM
	(
---------------------------------------------------------------------------------------------------------------------Rule 1
		SELECT DISTINCT
			c.CaseID
			,[Rule] = '1' 
			,[Heading] = 'New Cases' 
		FROM
			Case_CTE AS c 
				INNER JOIN
			RuleOne_CTE AS r 
				ON r.CaseID = c.CaseID
				AND r.RuleOneDt BETWEEN @Start AND DATEADD(DAY,1,@End)

		UNION ALL
---------------------------------------------------------------------------------------------------------------------Rule 2
		SELECT
			c.CaseID
			,[Rule] = '2' 
			,[Heading] = 'West Pre-Charge' 
		FROM
			Case_CTE AS c 
				LEFT OUTER JOIN
			CaseAgency_CTE AS ca
				ON c.CaseID = ca.CaseID
				--AND ca.CaseAgencyAddDt BETWEEN @Start AND DATEADD(DAY,1,@End
				AND c.CaseReceivedDt BETWEEN @Start AND DATEADD(DAY,1,@End)
		WHERE
			c.CaseTypeCode = 'CTWST' --WestPC
		
		UNION ALL
---------------------------------------------------------------------------------------------------------------------Rule 3
	(
		SELECT
			c.CaseID
			,[Rule] = '3'
			,[Heading] = 'Reopened Cases'
		FROM
			Case_CTE AS c
				INNER JOIN
			CaseAgency_CTE AS ca
					ON ca.CaseID = c.CaseID
				CROSS APPLY
			(
				SELECT TOP 1
					e.EventDt
					,e.EventID
				FROM
					jw50_Event AS e
				WHERE
					e.CaseID = c.CaseID
					AND e.EventTypeCode = 'CS01'--open event type
					AND e.EventDt BETWEEN @Start AND DATEADD(DAY,1,@End)
				ORDER BY
					e.EventDt DESC
			) AS opene3
				CROSS APPLY
			(
				SELECT TOP 1
					e2.EventDt
				,	e2.EventID
				,	e2.EventTypeCode
				FROM
					jw50_Event AS e2
				WHERE
					e2.CaseID = c.CaseID
					AND e2.EventTypeCodeType = 1 --case status
					AND e2.EventID != opene3.EventID
					AND e2.EventDt < opene3.EventDt --case statuses of warrent, hired private council, dpa removed, and pro se happen before case status of open
				ORDER BY
					e2.EventDt DESC
			) AS courte
				CROSS APPLY
			(
				SELECT TOP 1
					e3.EventDt
					,e3.EventID
					,e3.EventTypeCode
				FROM
					jw50_Event AS e3
				WHERE
					e3.CaseID = c.CaseID
					AND e3.EventTypeCode IN ('CS03','CS04','CS09','CS11','CSA14') --Added additional code
					AND e3.EventID = courte.EventID
				ORDER BY
					e3.EventDt DESC
			) AS rule3
		WHERE
			c.CaseTypeCode IN ('CT16','CTCE','CTDMV','CTFEL','CTJUV','CTJVA','CTMIS','CTOTH','CTPPR','CTREV','CTWRT') --Trial Court Cases
			AND ca.CaseAgencyMasterCode = 2 --Courts
			AND ca.CaseAgencyNumber IS NOT NULL
			
		EXCEPT --Can cases have multiple court numbers here? If so then the EXCEPT needs to take this into account
				
		SELECT DISTINCT
			c.CaseID
			,[Rule] = '3' 
			,[Heading] = 'Reopened Cases' 
		FROM
			Case_CTE AS c 
				INNER JOIN
			RuleOne_CTE AS r 
				ON r.CaseID = c.CaseID
				AND r.RuleOneDt BETWEEN @Start AND DATEADD(DAY,1,@End)
		)
		
		UNION ALL
---------------------------------------------------------------------------------------------------------------------Rule 4
		SELECT DISTINCT
			c.CaseID
			,[Rule] = '4' 
			,[Heading] = 'Contempt Cases' 
		FROM
			Case_CTE AS c
				INNER JOIN
			CaseAgency_CTE AS ca
					ON ca.CaseID = c.CaseID
				OUTER APPLY----------------------------------------------------------------------------------------
			(				--How is it ensured that the charges were entered after the case was re-opened?
				SELECT
					EventTypeCode
				FROM
					jw50_Event
				WHERE
					CaseID = c.CaseID
					AND EventTypeCode = 'CS01'
			) AS opene4
				CROSS APPLY
			(
				SELECT
					EventID
				FROM
					jw50_Event
				WHERE
					CaseID = c.CaseID
					AND EventTypeCodeType = 1 --only looking at events where the case status is changed
					AND EventTypeMasterCode = 2 --Case Status master of closed
			) AS csc4
				CROSS APPLY
			(
				SELECT
					CountID
					,CountIncidentDt
				FROM
					jw50_Count
				WHERE
					CaseID = c.CaseID
					AND StatuteChargeID IN ('26480','26581','26482','2693','26930','2648','1150','11500')  --New charges of contempt
			) AS contempt
				CROSS APPLY
			(
				SELECT
					CountID
				FROM
					jw50_Count
				WHERE
					CaseID = c.CaseID
					AND CountID != contempt.CountID --pulling all cases where the count IDs aren't contempt	 
			) AS cc
		WHERE
			contempt.CountIncidentDt BETWEEN @Start AND DATEADD(DAY,1,@End) --contempt cases added in the date range
			AND c.CaseTypeCode IN ('CT16','CTCE','CTDMV','CTFEL','CTJUV','CTJVA','CTMIS','CTOTH','CTPPR','CTREV','CTWRT') --Trial Court Cases
			AND ca.CaseAgencyMasterCode = 2 --Courts
			AND ca.CaseAgencyNumber IS NOT NULL
		
		UNION ALL
---------------------------------------------------------------------------------------------------------------------Rule 5
		SELECT DISTINCT
			c.CaseID
			,[Rule] = '5' 
			,[Heading] = 'Probation Violation Cases' 
		FROM
			Case_CTE AS c
				INNER JOIN
			CaseAgency_CTE AS ca
					ON ca.CaseID = c.CaseID
				INNER JOIN
			jw50_Count AS pv
					ON pv.CaseID = c.CaseID
					AND pv.StatuteChargeID IN ('26680','26800','26910','26911','26912') --new charges of probation violation, conditional discharge violation and pretrial deiversion violation
					AND pv.CountIncidentDt BETWEEN @Start AND DATEADD(DAY,1,@End)
		WHERE
			c.CaseTypeCode IN ('CT16','CTCE','CTDMV','CTFEL','CTJUV','CTJVA','CTMIS','CTOTH','CTPPR','CTREV','CTWRT') --Trial Court Cases
			AND ca.CaseAgencyMasterCode = 2 --Courts
			AND ca.CaseAgencyNumber IS NOT NULL
		
		UNION ALL
---------------------------------------------------------------------------------------------------------------------Rule 6
		SELECT
			c6.CaseID
			,[Rule] = '6' 
			,[Heading] = 'Revocation Cases' 
		FROM
			Case_CTE AS c6
				LEFT JOIN
			CaseAgency_CTE AS ca
					ON ca.CaseID = c6.CaseID
					AND ca.CaseAgencyAddDt BETWEEN @Start AND DATEADD(DAY,1,@End)
		WHERE
			c6.CaseTypeCode = 'CTREV' --Revocation cases
			AND NOT EXISTS (
								SELECT TOP 1 
									ca2.CaseAgencyNumber 
								FROM 
									CaseAgency_CTE AS ca2
								WHERE 
									ca2.CaseID = c6.CaseID
									AND ca2.CaseAgencyMasterCode = 2 --Court
									AND ca2.CaseAgencyNumber IS NOT NULL
							)
	) AS temp)

SELECT DISTINCT
	c.CaseID
	,OfficeCaseCount = COUNT(CourtNum) OVER (PARTITION BY Office)
	,CaseCountTotal = COUNT(CourtNum) OVER (PARTITION BY [Static])
	,m.Office
	,m.OfficeCode
	,c.[Rule]
	,c.Heading
	,m.Client
	,m.CaseTitle
	,m.CaseTypeCode
	,m.CaseTypeDesc
	,AttorneyID = ISNULL(a.AttorneyID, 0) 
	,Attorney = ISNULL(a.Attorney,'No Active Public Defender') 
	,AttyInvolvement = ISNULL(a.InvolveTypeDesc, 'N/A') 
	,AttyCount = COUNT(a.AttorneyID) OVER (PARTITION BY [Static])
	,NumWithAtty = COUNT(a.NoAttyCount) OVER (PARTITION BY [Static])
	,atc.NumOfAtty
	,atc.CaseInvPersActiveDt
	,atc.CaseInvPersNameID
	,m.County
	,m.Court
	,m.CourtNum
	,Judge = j.Attorney
	,m.NumAttyOffice
	,o.NumAttyOfficeTotal
	,MostSevereCharge = ISNULL(s.StatuteClassDesc,'No Statute') 
	,[Static]
FROM
	CaseCountRules_CTE AS c 
		LEFT OUTER JOIN
	Main_CTE AS m
			ON c.CaseID = m.CaseID
	OUTER APPLY
(
	SELECT
		aty.CaseID
		,AttorneyID = aty.CaseInvPersNameID
		,Attorney = aty.CaseInvPersFullName
		,aty.CaseInvPersActive
	FROM
		CaseInvPers_CTE AS aty
	WHERE
		aty.CaseAgencyID = m.CourtID
		AND aty.InvolveTypeCode = 'CIT03'
		AND 1 = CASE
					WHEN @Start BETWEEN CaseInvPersActiveDt AND CaseInvPersInactiveDt THEN 1
					WHEN CaseInvPersActiveDt >= @Start AND CaseInvPersInactiveDt <= @End THEN 1
					WHEN @End BETWEEN CaseInvPersActiveDt AND CaseInvPersInactiveDt THEN 1
					WHEN CaseInvPersActiveDt <= @Start AND CaseInvPersInactiveDt >=@End THEN 1
					WHEN CaseInvPersActive = 1 AND CaseInvPersActiveDt <= @End THEN 1
					ELSE 0
				END
) AS j
	OUTER APPLY
(
	SELECT TOP 1
		ISNULL(co.StatuteDesc,'No Statutes') AS StatuteRanked
		,co.CaseID
		,co.StatuteClassDesc
	FROM
		jw50_Count co
			CROSS APPLY
		(
			SELECT TOP 1
				Notes
			FROM
				jw50_StatuteClassType
			WHERE
				Code = co.StatuteClassCode
		) AS sc
	WHERE
		co.CaseID = c.CaseID
	ORDER BY
		sc.Notes
		,co.CountNum ASC
) AS s
	OUTER APPLY
(
	SELECT TOP 1
		COUNT(CaseInvPersNameID) OVER (PARTITION BY CaseID) AS NumOfAtty
		,CaseInvPersActiveDt
		,CaseInvPersNameID
	FROM
		CaseInvPers_CTE
	WHERE
		CaseID = c.CaseID
		AND InvolveTypeCode IN ('CIT06','CIT19','CONTR','CIT22')
	ORDER BY
		CaseInvPersActiveDt ASC
) AS atc
	OUTER APPLY
(
	SELECT
		aty.CaseID
		,NoAttyCount = aty.CaseAgencyDesc
		,AttorneyID = aty.CaseInvPersNameID
		,aty.InvolveTypeDesc
		,aty.CaseAgencyNameID
		,Attorney = aty.CaseInvPersFullName
		,aty.CaseInvPersNameID
	FROM
		CaseInvPers_CTE AS aty
			OUTER APPLY
		(
			SELECT
				CaseAgencyNameID
			FROM
				CaseInvPers_CTE
			WHERE
				CaseID = c.CaseID
				AND CaseInvPersNameID = aty.ForCaseInvPersNameID
				AND InvolveTypeCode = 'CIT03'
		) AS jcheck
	WHERE
		aty.CaseID = c.CaseID
		AND aty.InvolveTypeCode IN ('CIT06','CIT19')
		AND (--jcheck.CaseAgencyNameID = m.CaseAgencyNameID OR 
		aty.CaseInvPersNameID = atc.CaseInvPersNameID)
		AND 1 = CASE 
					WHEN c.[Rule] = 1 THEN CASE
												WHEN atc.NumOfAtty > 1 THEN
																			CASE
																				--WHEN jcheck.CaseInvPersNameID IS NOT NULL
																				
																				WHEN @Start BETWEEN CaseInvPersActiveDt AND CaseInvPersInactiveDt THEN 1
																				WHEN CaseInvPersActiveDt >= @Start AND CaseInvPersInactiveDt <= @End THEN 1
																				WHEN @End BETWEEN CaseInvPersActiveDt AND CaseInvPersInactiveDt THEN 1
																				WHEN CaseInvPersActiveDt <= @Start AND CaseInvPersInactiveDt >=@End THEN 1
																				WHEN CaseInvPersActive = 1 AND CaseInvPersActiveDt <= @End THEN 1
																				ELSE 0
																			END
												ELSE 1
											END
					WHEN c.[Rule] = 2 THEN 1
					WHEN c.[Rule] = 3 THEN 1
					WHEN c.[Rule] = 4 THEN 1
					WHEN c.[Rule] = 5 THEN 1
					WHEN c.[Rule] = 6 THEN 1
				END
											
) AS a
	LEFT JOIN
OfficeList_CTE AS o 
		ON o.AgencyCode = m.OfficeCode	
WHERE
	--m.OfficeCode IN (@OfficeCode)
	OfficeCode IN (SELECT VALUE FROM @OfficeCode)
	AND m.CaseStatusCode NOT IN ('CS10','CS20')
	and c.CaseID IN ('14-14','14-15')
ORDER BY
	CaseID
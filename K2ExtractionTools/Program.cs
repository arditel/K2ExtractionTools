using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Configuration;
using SourceCode.Workflow.Client;
using SourceCode.Hosting.Client.BaseAPI;
using K2ExtractionLibrary.DAL;
using K2ExtractionLibrary.Model;

namespace K2ExtractionTools
{
    class Program
    {
        private static SCConnectionStringBuilder _connection;
        private static string _connectionString;
        private static string _k2User;
        private static Program _instance;
        
        private const string PERCENT = "%";
        private const string PREFIX_K2USER = "K2:";
        private const string POLICY_NAMESPACE = "Policy";

        public Program()
        {
        }

        public static Program GetInstance()
        {
            if (_instance == null)
                _instance = new Program();
            return _instance;
        }

        static void Main(string[] args)
        {            
            LoadConfiguration();
            ProcessK2Data();
        }

        private static void LoadConfiguration()
        {
            _k2User = ConfigurationManager.AppSettings["K2User"];
        }

        private static SCConnectionStringBuilder Connection
        {
            get
            {
                return _connection ?? (_connection = new SCConnectionStringBuilder
                {
                    Host = ConfigurationManager.AppSettings["K2ServerAddress"],
                    Port = Convert.ToUInt32(ConfigurationManager.AppSettings["K2Port"]),
                    UserID = _k2User,
                    Password = ConfigurationManager.AppSettings["K2Password"],
                    IsPrimaryLogin = true,
                    SecurityLabelName = "K2",
                    Integrated = false
                });
            }
        }

        private static string ConnectionString
        {
            get
            {
                if (string.IsNullOrEmpty(_connectionString))
                    _connectionString = Connection.ToString();

                return _connectionString;
            }
        }

        private string GetLastUserFromReferenceNo(string referenceNo)
        {            
            return new WTWorkflowTaskDataDAL().GetLastUserFromReferenceNo(referenceNo,POLICY_NAMESPACE);
        }        

        private Int32 ProcessWTWorkflowTaskDataPIC(WTWorkflowTaskDataEntities entity)
        {
            return new WTWorkflowTaskDataDAL().ProcessWTWorkflowTaskDataPIC(entity, POLICY_NAMESPACE);
        }

        private void InsertWTWorkflowDataField(WTWorkflowDataFieldEntities entity)
        {
            new WTWorkflowTaskDataDAL().InsertWTWorkflowDataField(entity, POLICY_NAMESPACE);
        }

        private IList<WorkflowDataProcessedEntities> WorkflowTaskDataProcessed()
        {
            return new WTWorkflowTaskDataDAL().WorkflowTaskDataProcessed();
        }

        public static void ProcessK2Data()
        {
            int procInstId = 0;
            IList<WorkflowDataProcessedEntities> listData = new List<WorkflowDataProcessedEntities>();
            listData = GetInstance().WorkflowTaskDataProcessed().OrderBy(x => x.WTWorkflowTaskDataID).ToList();

            foreach (var item in listData)
            {
                var data = GetK2TaskDataFromReferenceNo(item.ReferenceNo);
                procInstId = GetInstance().ProcessWTWorkflowTaskDataPIC(data);
                GetK2DataField(procInstId, item.ReferenceNo);
            }
        }

        public static WTWorkflowTaskDataEntities GetK2TaskDataFromReferenceNo(string referenceNo)
        {
            WTWorkflowTaskDataEntities workflowTaskData = new WTWorkflowTaskDataEntities();
            var connection = new Connection();

            WorklistCriteria _worklistCriteria = new WorklistCriteria();
            _worklistCriteria.AddFilterField(WCLogical.AndBracket, WCField.ProcessFolio, WCCompare.Like, string.Concat(PERCENT, referenceNo, PERCENT));

            string userLogID = string.Empty;
            userLogID = GetInstance().GetLastUserFromReferenceNo(referenceNo);
            
            try
            {
                connection.Open(ConfigurationManager.AppSettings["K2ServerAddress"], ConnectionString);

                connection.ImpersonateUser(string.Concat(PREFIX_K2USER, userLogID));
                
                var worklistData = connection.OpenWorklist(_worklistCriteria);
                var _worklist = (from t in worklistData.OfType<WorklistItem>() select t).ToList<WorklistItem>().FirstOrDefault();

                //foreach (WorklistItem _item in _worklist)
                //{
                //    Console.WriteLine("SerialNo : " + _item.SerialNumber);
                //    Console.WriteLine("ReferenceNo : " + _item.ProcessInstance.DataFields["ReferenceNo"].Value as string);
                //    Console.WriteLine("CanvasName :" + _item.ProcessInstance.Name);
                //    Console.WriteLine("WorkflowStageCode :" + _item.ProcessInstance.DataFields["StageCode"].Value as string);
                //    Console.WriteLine("Folio :" + _item.ProcessInstance.Folio);
                //    Console.WriteLine("Originator :" + _item.ProcessInstance.Originator.Name);
                //    Console.WriteLine("Status :" + _item.ProcessInstance.Status1);                    
                //}

                workflowTaskData.SerialNo = _worklist.SerialNumber;
                workflowTaskData.ReferenceNo = _worklist.ProcessInstance.DataFields["ReferenceNo"].Value as string;
                workflowTaskData.CanvasName = _worklist.ProcessInstance.Name;
                workflowTaskData.WorkflowStageCode = _worklist.ProcessInstance.DataFields["StageCode"].Value as string;
                workflowTaskData.Folio = _worklist.ProcessInstance.Folio;
                workflowTaskData.Originator = _worklist.ProcessInstance.Originator.Name;
                workflowTaskData.Status = _worklist.ProcessInstance.Status1.ToString();

                connection.Close();
            }
            catch(Exception ex)
            {
                Console.WriteLine(ex);
            }
            finally
            {                
                connection.Close();
                connection.Dispose();
            }

            return workflowTaskData;
        }

        public static void GetK2DataField(int procIntsID, string referenceNo)
        {
            WTWorkflowDataFieldEntities dataField;
            var connection = new Connection();

            try
            {
                connection.Open(ConfigurationManager.AppSettings["K2ServerAddress"],ConnectionString);
                ProcessInstance objProcessInst = connection.OpenProcessInstance(Convert.ToInt32(procIntsID));
                foreach (DataField dField in objProcessInst.DataFields)
                {
                    dataField = new WTWorkflowDataFieldEntities();
                    dataField.ReferenceNo = referenceNo;
                    dataField.DataFieldName = dField.Name;
                    dataField.DataFieldValue = dField.Value.ToString();
                    
                    GetInstance().InsertWTWorkflowDataField(dataField);

                    //Console.WriteLine(dField.Name + "\t" + dField.Value);
                }
                connection.Close();
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex);
            }
            finally
            {
                connection.Close();
            }            
        }
    }
}

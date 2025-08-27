@isTest
public class TaskUtilTest {
  @isTest
  static void testTaskPriority() {
    String pri = TaskUtil.getTaskPriority('NY');
    System.assertEquals('Normal', pri);
  }    
}
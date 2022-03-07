import CoreData
import XCTest

class SentryCoreDataTrackingIntegrationTests: XCTestCase {

    private class Fixture {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        
        func getSut() -> SentryCoreDataTrackingIntegration {
            return SentryCoreDataTrackingIntegration()
        }
        
        func testEntity() -> TestEntity {
            let entityDescription = NSEntityDescription()
            entityDescription.name = "TestEntity"
            return TestEntity(entity: entityDescription, insertInto: context)
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func test_InstallAndUninstall() {
        let sut = fixture.getSut()
        
        let options = Options()
        options.enableSwizzling = true
        
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.install(with: options)
        XCTAssertNotNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.uninstall()
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
    }
    
    func test_Install_swizzlingDisabled() {
        let sut = fixture.getSut()
        
        let options = Options()
        options.enableSwizzling = false
        
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
        sut.install(with: options)
        XCTAssertNil(SentryCoreDataSwizzling.sharedInstance.middleware)
    }
    
}

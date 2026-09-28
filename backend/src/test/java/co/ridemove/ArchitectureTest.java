package co.ridemove;

import com.tngtech.archunit.core.importer.ClassFileImporter;
import org.junit.jupiter.api.Test;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

class ArchitectureTest {
    @Test void coreDoesNotKnowFrameworksOrAdapters() {
        var classes=new ClassFileImporter().importPackages("co.ridemove");
        noClasses().that().resideInAnyPackage("..domain..","..application..")
                .should().dependOnClassesThat().resideInAnyPackage("org.springframework..","jakarta..","..adapter..","..bootstrap..","com.fasterxml..")
                .check(classes);
    }
    @Test void domainDoesNotDependOnApplication() {
        noClasses().that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAPackage("..application..")
                .check(new ClassFileImporter().importPackages("co.ridemove"));
    }
}

import VietMapNavigation
import VietMapDirections

extension SpotARNavigationViewController: VisualInstructionDelegate {
    public func label(_ label: InstructionLabel, willPresent instruction: VisualInstruction, as presented: NSAttributedString) -> NSAttributedString? {        
        return presented
    }
}

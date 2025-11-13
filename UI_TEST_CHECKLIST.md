# DBC File Viewer - UI Test Checklist

## 1. Application Launch & Initial State

### Startup
- [ ] Application launches without errors
- [ ] Window maximizes to full screen correctly
- [ ] Window title displays "DBC File Viewer"
- [ ] Default theme (Dark/Light) loads correctly
- [ ] Material theme colors (Green accent/primary) are visible
- [ ] No error messages on startup

### Initial UI State
- [ ] All four tabs are visible (Messages, Signals, TCP Client, About)
- [ ] Messages tab is selected by default
- [ ] Header shows "DBC File Viewer" title
- [ ] Load DBC File button is visible and enabled
- [ ] Theme toggle button is visible
- [ ] Connection status indicator is visible

---

## 2. Theme Switching

### Theme Toggle
- [ ] Theme toggle button responds to clicks
- [ ] UI switches between Dark and Light themes
- [ ] All panels update colors correctly
- [ ] Text remains readable in both themes
- [ ] Borders and accents update properly
- [ ] Notification colors adapt to theme
- [ ] Dialog backgrounds update with theme
- [ ] Grid colors in Bit Editor update with theme

---

## 3. File Loading

### DBC File Dialog
- [ ] "Load DBC File" button opens file dialog
- [ ] File dialog filters for .dbc files only
- [ ] File dialog allows navigation to different directories
- [ ] Dialog can be cancelled without errors
- [ ] Previously selected folder is remembered (if applicable)

### File Loading Process
- [ ] Selected file path is displayed in status
- [ ] Loading shows success notification
- [ ] Messages populate in Messages tab
- [ ] Signals populate in Signals tab
- [ ] Invalid file shows error message
- [ ] Empty/corrupt file handled gracefully
- [ ] Large files load without freezing UI

---

## 4. Messages Tab

### Message List Display
- [ ] Messages list displays after DBC load
- [ ] Message ID shows in hex format (0x...)
- [ ] Message name is readable and not truncated
- [ ] DLC (Data Length Code) displays correctly
- [ ] Scrollbar appears for long lists
- [ ] List is searchable/filterable (if implemented)
- [ ] Selection highlighting works

### Message Operations
- [ ] "Add Message" button opens Add Message dialog
- [ ] Clicking a message selects it
- [ ] Selected message is highlighted
- [ ] Delete mode toggle works
- [ ] Checkboxes appear in deletion mode
- [ ] "Select All" button selects all messages
- [ ] "Deselect All" button clears selections
- [ ] Selected count displays correctly
- [ ] Delete button removes selected messages
- [ ] Deletion confirmation dialog appears
- [ ] Cancel deletion mode restores normal view

### Send Message Button
- [ ] Send button appears for each message
- [ ] Send button opens Send Message dialog
- [ ] Send button is disabled when not connected (if applicable)
- [ ] Send button tooltip shows correct info

### Context Menu (if implemented)
- [ ] Right-click shows context menu
- [ ] Edit option works
- [ ] Delete option works
- [ ] Copy option works

---

## 5. Add Message Dialog

### Dialog Display
- [ ] Dialog opens centered on screen
- [ ] Dialog is modal (blocks main window)
- [ ] Header shows "Add New CAN Message"
- [ ] All input fields are visible
- [ ] Close button (X) works
- [ ] Dialog adapts to current theme

### Input Fields
- [ ] Message Name field accepts text input
- [ ] Message ID field accepts hex values
- [ ] Message ID validates hex format
- [ ] DLC field accepts numeric values
- [ ] DLC field validates range (0-8)
- [ ] Required field validation works
- [ ] Tab navigation between fields works
- [ ] Fields can be cleared

### Dialog Actions
- [ ] "Add" button creates message
- [ ] Success notification appears
- [ ] New message appears in list
- [ ] Dialog closes after successful add
- [ ] "Cancel" button closes dialog without adding
- [ ] Invalid input shows error message
- [ ] Duplicate ID shows error/warning
- [ ] Empty fields prevent submission

---

## 6. Signals Tab

### Signal List Display
- [ ] Signals list displays after DBC load
- [ ] Signal name is visible
- [ ] Parent message name shows
- [ ] Start bit displays correctly
- [ ] Signal length displays correctly
- [ ] Byte order (Little/Big Endian) shows
- [ ] Factor and offset display (if shown)
- [ ] Units display (if applicable)
- [ ] Scrollbar appears for long lists

### Signal Operations
- [ ] "Add Signal" button opens Add Signal dialog
- [ ] Clicking a signal selects it
- [ ] Delete mode toggle works
- [ ] Checkboxes appear in deletion mode
- [ ] "Select All" button selects all signals
- [ ] "Deselect All" button clears selections
- [ ] Selected count displays correctly
- [ ] Delete button removes selected signals
- [ ] Deletion confirmation dialog appears
- [ ] Cancel deletion mode restores normal view

### Signal Editing
- [ ] Double-click opens edit dialog (if implemented)
- [ ] Edit button works
- [ ] Value changes are saved
- [ ] Invalid values are rejected

---

## 7. Add Signal Dialog

### Dialog Display
- [ ] Dialog opens centered on screen
- [ ] Dialog is modal
- [ ] Header shows "Add New Signal"
- [ ] All input fields are visible
- [ ] Width is sufficient (650px)
- [ ] Height is appropriate (700px)
- [ ] Close button works
- [ ] Dialog adapts to current theme

### Input Fields - Basic
- [ ] Signal Name field accepts text
- [ ] Message dropdown shows available messages
- [ ] Message selection updates current message
- [ ] Start Bit field accepts numbers (0-63)
- [ ] Start Bit validates range
- [ ] Length field accepts numbers (1-64)
- [ ] Length validates range
- [ ] Byte Order dropdown (Little/Big Endian)

### Input Fields - Advanced
- [ ] Factor field accepts decimal numbers
- [ ] Offset field accepts decimal numbers
- [ ] Minimum value field accepts numbers
- [ ] Maximum value field accepts numbers
- [ ] Unit field accepts text
- [ ] Value type dropdown works (Signed/Unsigned)
- [ ] All numeric fields validate input

### Bit Layout Visualization (if present)
- [ ] Bit grid displays correctly
- [ ] Selected bits highlight in green/blue
- [ ] Bit indices show (63-0 or 0-63)
- [ ] Little Endian layout is correct
- [ ] Big Endian layout is correct
- [ ] Overlapping bits show error/warning

### Dialog Actions
- [ ] "Add" button creates signal
- [ ] Success notification appears
- [ ] New signal appears in list
- [ ] Dialog closes after successful add
- [ ] "Cancel" button closes without adding
- [ ] Invalid input shows error popup
- [ ] Error popup displays correct message
- [ ] Error popup "OK" button works
- [ ] Overlapping bits prevent addition
- [ ] Empty required fields prevent submission

---

## 8. Send Message Dialog

### Dialog Display
- [ ] Dialog opens centered on screen
- [ ] Dialog is modal
- [ ] Header shows "Send CAN Message"
- [ ] Subtitle shows "Configure message transmission settings"
- [ ] Dialog width is 750px
- [ ] Dialog height is 750px
- [ ] Dialog adapts to current theme

### Message Information
- [ ] Message name displays correctly
- [ ] Message ID displays in hex format
- [ ] Message DLC shows correctly
- [ ] Current hex data displays
- [ ] Hex data field is editable

### Signal Value Editors
- [ ] All signals for message display
- [ ] Each signal has a value input field
- [ ] Signal names are visible
- [ ] Current values display
- [ ] Sliders work (if present)
- [ ] Text input updates values
- [ ] Invalid values are rejected
- [ ] Min/max bounds are enforced
- [ ] Physical value calculation is correct
- [ ] Hex data updates as values change

### CAN Bus Selection
- [ ] CAN bus dropdown displays
- [ ] Available buses are listed (vcan0, etc.)
- [ ] Selected bus is highlighted
- [ ] Default bus is vcan0

### Transmission Settings
- [ ] Transmission rate field displays
- [ ] Rate field accepts numeric values (ms)
- [ ] Rate validates minimum value (1ms or higher)
- [ ] Default rate is 100ms
- [ ] Rate can be adjusted while sending

### Connection Status
- [ ] Connection status indicator visible
- [ ] Status shows "Connected" when connected
- [ ] Status shows "Disconnected" when not connected
- [ ] Status color changes (green/red)
- [ ] Status updates in real-time

### Send Actions
- [ ] "Send Once" button works
- [ ] "Start Transmission" button starts periodic send
- [ ] Button text changes to "Stop Transmission"
- [ ] "Stop Transmission" button stops sending
- [ ] Transmission status displays
- [ ] Success messages appear
- [ ] Error messages appear on failure
- [ ] Cannot send when disconnected
- [ ] Status auto-hides after 3 seconds

### Dialog Actions
- [ ] "Close" button closes dialog
- [ ] Closing dialog stops transmission
- [ ] Dialog state persists if reopened (optional)

---

## 9. Bit Editor Component

### Editor Display
- [ ] Bit Editor opens when signal is selected
- [ ] Editor displays signal name
- [ ] Close button (×) works
- [ ] Panel has proper border and styling
- [ ] Background color matches theme

### Value Input Section
- [ ] Physical Value field displays current value
- [ ] Physical Value field is editable
- [ ] Raw Value field displays calculated raw value
- [ ] Raw Value field is editable
- [ ] Values update in real-time
- [ ] Invalid values are rejected
- [ ] Decimal values work correctly

### Bit Grid Display
- [ ] Bit grid shows 8 bytes (64 bits)
- [ ] Bit indices display (63, 62, ..., 1, 0 or 0-63)
- [ ] Each bit cell is clickable
- [ ] Signal bits are highlighted (green/blue)
- [ ] Non-signal bits are grayed out
- [ ] Bit order matches endianness (Little/Big)
- [ ] Grid layout is readable

### Bit Grid Interaction
- [ ] Clicking bits toggles their value
- [ ] Bit changes update raw value
- [ ] Raw value changes update physical value
- [ ] Physical value changes update bits
- [ ] Calculation formula displays
- [ ] Formula shows factor and offset
- [ ] Hex representation updates

### Signal Mask Visualization
- [ ] Signal mask grid shows signal coverage
- [ ] Masked bits are clearly visible
- [ ] Mask matches signal definition
- [ ] Endianness is correctly represented

---

## 10. TCP Client Tab

### Connection Interface
- [ ] TCP Client tab is accessible
- [ ] Server IP field displays
- [ ] Server Port field displays
- [ ] IP field accepts valid IP format
- [ ] Port field accepts valid port numbers
- [ ] Default values are shown (if any)

### Connection Status
- [ ] Status indicator (dot) is visible
- [ ] Indicator is red when disconnected
- [ ] Indicator is green when connected
- [ ] Status text shows "Connected"/"Disconnected"
- [ ] Status updates immediately on change

### Connection Actions
- [ ] "Connect" button attempts connection
- [ ] Button changes to "Disconnect" when connected
- [ ] "Disconnect" button disconnects
- [ ] Connection errors show error message
- [ ] Timeout is handled gracefully
- [ ] Reconnection attempts work

### Message History
- [ ] Message history area displays
- [ ] System messages appear (connection events)
- [ ] Sent messages are logged with timestamp
- [ ] Received messages are logged with timestamp
- [ ] Message types are color-coded
- [ ] Auto-scroll to latest message works
- [ ] History is clearable (if button present)
- [ ] Timestamps are in correct format (hh:mm:ss)

### Send/Receive Interface
- [ ] Manual message send field works (if present)
- [ ] Send button is enabled when connected
- [ ] Send button is disabled when disconnected
- [ ] Responses are displayed in history
- [ ] Long messages are wrapped properly

---

## 11. About Tab

### Content Display
- [ ] About tab is accessible
- [ ] Application name displays
- [ ] Version number displays (if present)
- [ ] Credits/authors are listed
- [ ] Functionality overview is readable
- [ ] Description is properly formatted
- [ ] Links work (if any)
- [ ] Text is scrollable if long

### Styling
- [ ] Content follows theme colors
- [ ] Text is readable
- [ ] Sections are well-organized
- [ ] Icons/images display correctly (if any)

---

## 12. Notifications System

### Notification Display
- [ ] Notifications appear in designated area
- [ ] Notifications stack vertically
- [ ] Each notification has correct color:
  - [ ] Success = Green
  - [ ] Error = Red
  - [ ] Warning = Orange/Yellow
  - [ ] Info = Blue/Gray
- [ ] Notification text is readable
- [ ] Icon matches type (if icons used)

### Notification Behavior
- [ ] Notifications auto-dismiss after timeout
- [ ] Timeout is reasonable (3-5 seconds)
- [ ] User can manually close notifications
- [ ] Close button (×) works
- [ ] Multiple notifications don't overlap
- [ ] Notifications animate in/out smoothly
- [ ] Long text is wrapped properly

### Notification Triggers
- [ ] File load success/error notifications
- [ ] Message add success/error notifications
- [ ] Signal add success/error notifications
- [ ] Connection status change notifications
- [ ] Message send status notifications
- [ ] Transmission start/stop notifications
- [ ] Delete operation notifications

---

## 13. Deletion Mode

### Activation
- [ ] Delete mode toggle button works
- [ ] UI changes when entering delete mode
- [ ] Checkboxes appear next to items
- [ ] Normal action buttons are hidden/disabled
- [ ] Delete mode buttons appear

### Selection
- [ ] Individual items can be selected via checkbox
- [ ] "Select All" selects all items
- [ ] "Deselect All" clears all selections
- [ ] Selection count updates in real-time
- [ ] Count text is visible and accurate

### Deletion
- [ ] Delete button is enabled when items selected
- [ ] Delete button shows confirmation dialog
- [ ] Confirmation dialog lists item count
- [ ] "Confirm" deletes selected items
- [ ] "Cancel" aborts deletion
- [ ] Success notification appears
- [ ] Selected items are removed from list
- [ ] Deletion mode exits after delete (optional)

### Cancellation
- [ ] "Cancel" button exits deletion mode
- [ ] Selections are cleared on cancel
- [ ] UI returns to normal state
- [ ] No items are deleted

---

## 14. Data Validation

### Numeric Fields
- [ ] Hex values reject non-hex characters
- [ ] Numeric fields reject letters
- [ ] Decimal fields accept decimal point
- [ ] Negative values work where appropriate
- [ ] Out-of-range values show error
- [ ] Empty required fields prevent submission

### Text Fields
- [ ] Text fields accept alphanumeric
- [ ] Special characters handled correctly
- [ ] Very long text is handled (truncation/scroll)
- [ ] Empty name fields show error

### Range Validation
- [ ] Message ID range (0x000-0x7FF or 0x0-0x1FFFFFFF)
- [ ] DLC range (0-8)
- [ ] Start Bit range (0-63)
- [ ] Signal Length range (1-64)
- [ ] Transmission Rate minimum (e.g., > 0)

---

## 15. Responsive Design

### Window Resizing
- [ ] Window can be resized
- [ ] UI elements reflow on resize
- [ ] Text doesn't overflow
- [ ] Buttons remain clickable
- [ ] Scrollbars appear when needed
- [ ] Minimum window size is reasonable

### Layout Adaptations
- [ ] Panels expand to fill space
- [ ] Lists adjust to available height
- [ ] Dialogs remain centered
- [ ] Header/footer stay positioned

---

## 16. Performance

### Responsiveness
- [ ] UI remains responsive during file load
- [ ] No freezing when scrolling long lists
- [ ] Smooth animations
- [ ] Fast theme switching
- [ ] Dialog open/close is instant
- [ ] Button clicks respond immediately

### Large Data Handling
- [ ] 100+ messages load without lag
- [ ] 500+ signals load without lag
- [ ] Scrolling is smooth with many items
- [ ] Search/filter is fast (if implemented)

---

## 17. Keyboard Navigation

### Tab Navigation
- [ ] Tab key moves between input fields
- [ ] Tab order is logical
- [ ] Shift+Tab moves backward
- [ ] Focus indicators are visible

### Shortcuts (if implemented)
- [ ] Ctrl+O opens file dialog
- [ ] Ctrl+S saves (if applicable)
- [ ] Esc closes dialogs
- [ ] Enter submits forms
- [ ] Delete key deletes selected items

---

## 18. Mouse Interaction

### Clicks
- [ ] Single click selects items
- [ ] Double click opens editor (if implemented)
- [ ] Right click shows context menu (if implemented)
- [ ] Click and drag scrolls (if applicable)

### Hover Effects
- [ ] Buttons highlight on hover
- [ ] Tooltips appear on hover
- [ ] List items highlight on hover
- [ ] Cursor changes appropriately (pointer, text, etc.)

---

## 19. Error Handling

### Error Messages
- [ ] File load errors display message
- [ ] Network errors display message
- [ ] Validation errors display message
- [ ] Error messages are clear and actionable
- [ ] Errors don't crash the application

### Recovery
- [ ] UI remains functional after errors
- [ ] Dialogs can be closed after error
- [ ] Can retry failed operations
- [ ] State is preserved where possible

---

## 20. Edge Cases

### Empty States
- [ ] Empty message list shows placeholder text
- [ ] Empty signal list shows placeholder text
- [ ] No DBC file loaded state is clear
- [ ] Disconnected TCP state is clear

### Boundary Conditions
- [ ] Maximum message ID (0x7FF/0x1FFFFFFF)
- [ ] Maximum DLC (8)
- [ ] Maximum signal length (64)
- [ ] Maximum signal value
- [ ] Minimum values (0)

### Unusual Data
- [ ] Special characters in names
- [ ] Very long names
- [ ] Unicode characters (if supported)
- [ ] Overlapping signals (error handling)
- [ ] Gaps in bit layout

---

## 21. Integration Testing

### Component Communication
- [ ] Message changes update signal list
- [ ] Signal changes update message data
- [ ] TCP connection affects send functionality
- [ ] Theme changes propagate to all components
- [ ] Notifications triggered from backend display correctly

### Data Consistency
- [ ] Hex data matches signal values
- [ ] Physical values match raw values
- [ ] Bit grid matches hex data
- [ ] Message list matches DBC content
- [ ] Signal list matches DBC content

---

## 22. Cross-Tab Consistency

### State Persistence
- [ ] Switching tabs preserves state
- [ ] Selected items remain selected
- [ ] Input field values persist
- [ ] Connection state is consistent across tabs
- [ ] Notifications persist across tab switches

---

## 23. Accessibility (Optional)

### Screen Reader Support
- [ ] Buttons have accessible labels
- [ ] Input fields have labels
- [ ] Error messages are announced
- [ ] Focus order is logical

### Visual Accessibility
- [ ] Sufficient color contrast
- [ ] Text is readable at default size
- [ ] Focus indicators are visible
- [ ] Color is not the only indicator

---

## Test Execution Notes

### Environment
- **OS:** _________________
- **Qt Version:** _________________
- **Screen Resolution:** _________________
- **Theme Tested:** Dark / Light / Both

### Test Results Summary
- **Total Tests:** _______
- **Passed:** _______
- **Failed:** _______
- **Blocked:** _______
- **Not Applicable:** _______

### Critical Issues Found
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Minor Issues Found
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Recommendations
_______________________________________________
_______________________________________________
_______________________________________________

---

## Testing Tips

1. **Test in both themes** - Many issues only appear in one theme
2. **Test with real DBC files** - Use actual CAN database files with varying complexity
3. **Test edge cases** - Try maximum values, empty inputs, special characters
4. **Test error paths** - Intentionally cause errors to verify handling
5. **Test performance** - Load large DBC files (100+ messages, 500+ signals)
6. **Test continuously** - Leave app running to check for memory leaks or degradation
7. **Test network conditions** - Try disconnecting/reconnecting TCP server
8. **Test rapid interactions** - Click buttons quickly, switch tabs rapidly

---

**Version:** 1.0  
**Last Updated:** November 13, 2025  
**Created For:** DBC File Viewer Qt Application

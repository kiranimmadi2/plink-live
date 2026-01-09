# Business Profile UI Design Prompts
## Comprehensive End-to-End Design System

**Design System Overview:**
- **Color Palette:** Deep blue primary (#1E3A5F), Bright blue accent (#2563EB), Light blue highlights (#3B82F6), Light grey background (#FAFAFA)
- **Typography:** Modern sans-serif, 28px bold headers, 15px body text, 14px labels
- **Spacing:** 20px padding, 12-16px gaps between elements
- **Border Radius:** 12px for containers, 25px for pills/chips
- **Shadows:** Subtle (0, 2) with 0.05 opacity for depth

---

## 1. WELCOME/ONBOARDING SPLASH SCREEN

**Prompt:**
Design a modern, clean welcome screen for a business profile setup app. Clean white background with subtle gradient overlay (very light blue tint). Center the screen with a large, elegant illustration of diverse business icons (store, restaurant, hotel, salon, clinic) arranged in a circle or floating pattern. Below the illustration, display bold headline text "Create Your Business Profile" in deep blue (#1E3A5F), 32px font. Subtitle below in grey (#6B7280), 16px: "Set up your professional presence in minutes". At the bottom, two prominent buttons: "Get Started" (bright blue #2563EB, white text, rounded 12px) and "Skip for Now" (outlined, grey text). Add progress dots at the bottom showing this is slide 1 of 3. Minimalist, professional, trustworthy aesthetic. Light grey (#F9FAFB) background.

---

## 2. CATEGORY SELECTION SCREEN (Step 1 of 6)

**Prompt:**
Design a business category selection screen with modern, clean UI. Top bar shows: back arrow (left), "Step 1 of 6" in grey (center), "16%" in blue (right). Below, a 4px blue progress bar filled 16%. Main heading: "What type of business do you have?" in bold, 28px, black (#111827), left-aligned. Subtitle below: "Select the category that best describes your business" in grey (#6B7280), 15px. Below that, a search bar with rounded corners (12px), white background, grey border, search icon (left), placeholder "Search categories...".

Below the search bar, display a 2-column grid of category cards (12px gap). Each card is white, rounded 12px, with subtle border. When unselected: grey border (#E5E7EB). When selected: bright blue border (#2563EB, 2px thick) with light blue shadow. Each card shows: icon (32px, centered, grey when unselected, blue when selected), category name below (14px, centered).

Categories to show: Hospitality (hotel icon), Food & Beverage (restaurant icon), Grocery (basket icon), Retail (store icon), Beauty & Wellness (spa icon), Healthcare (medical icon), Education (school icon), Fitness (dumbbell icon), Automotive (car icon), Real Estate (building icon), Travel & Tourism (plane icon), Entertainment (celebration icon), Pet Services (paw icon), Home Services (tools icon), Technology (computer icon), Legal (gavel icon), Professional Services (briefcase icon), Transportation (truck icon), Art & Creative (palette icon), Construction (hard hat icon), Agriculture (plant icon), Manufacturing (factory icon), Wedding & Events (cake icon).

Light grey background (#F9FAFB). Bottom fixed white bar with shadow, contains blue "Next" button with arrow icon (disabled grey when nothing selected, bright blue when selection made).

---

## 3. SUB-CATEGORY/SPECIALTY SELECTION (Step 2 of 6)

**Prompt:**
Design a business specialty selection screen. Top bar shows "Step 2 of 6" and "33%" progress (blue bar filled 33%). Bold heading: "What's your specialty?" (28px, black, left-aligned). Subtitle: "Choose your specific category" (15px, grey).

Display specialty options as pill-shaped chips arranged in a wrap layout (flowing left to right, wrapping to next line). Each chip: rounded 25px, horizontal padding 20px, vertical padding 12px, 14px text. Unselected state: white background, grey border (#E5E7EB), grey text (#6B7280). Selected state: bright blue background (#2563EB), white text, no border.

For "Hospitality" category, show chips: Hotel, Resort, Guesthouse, Hostel, Villa, Homestay, Motel, Service Apartment. For "Food & Beverage": Restaurant, Cafe, Bakery, Bar & Pub, Cloud Kitchen, Food Truck, Fast Food, Fine Dining, Catering, Ice Cream & Desserts. Space chips 10px apart horizontally and vertically.

Light grey background. Bottom white bar with "Back" (outlined, grey) and "Next" (blue, solid) buttons.

---

## 4. BASIC BUSINESS INFORMATION (Step 3 of 6)

**Prompt:**
Design a business information form screen. Top shows "Step 3 of 6" and 50% blue progress bar. Heading: "Tell us about your business" (28px, bold, black). Subtitle: "We'll use this information to set up your official profile" (15px, grey).

Form fields (vertical stack, 20px gaps):
1. **Business Name field**: Label "Business Name" with red asterisk (14px, grey text, medium weight), below it white rounded input (12px radius) with store icon (left), placeholder "e.g. Joe's Coffee Shop", grey border becoming blue on focus.

2. **Legal Name field**: Label "Legal Name" (14px, grey), white rounded input with badge icon, placeholder "e.g. Joe's Coffee LLC", helper text below in small grey italic "Only required if different from your business name."

3. **Logo Upload section**: Label "Business Logo" (14px, grey). Large white rounded container (12px) with dashed grey border. If no logo: grey rounded square placeholder (80px) with photo icon (40px, grey), text below "Tap to upload your logo" (14px, grey, medium), smaller text "PNG, JPG up to 5MB" (12px, light grey). If logo uploaded: show image in rounded square (100px), with "Change" and "Remove" text buttons below (blue and red respectively). Helper text: "A good logo helps customers recognize your business" (12px, light grey).

Light grey background. Bottom bar with "Back" and "Next" buttons.

---

## 5. LOCATION SETUP (Step 4 of 6)

**Prompt:**
Design a business location input screen. Top shows "Step 4 of 6" and 66% blue progress bar. Heading: "Where is your business located?" (28px, bold, black). Subtitle: "This address will be visible to your customers" (15px, grey).

**Search Address section**:
- Label "Search Address" (14px, grey)
- Search input field: white rounded (12px), search icon (left), placeholder "Search for your business address...", loading spinner shows on right when searching
- If results appear: white dropdown container below (12px rounded, grey border) with max height 200px, scrollable list of location results. Each result: location pin icon (blue) on left, address text (14px, black), tap area. Max 5 results shown.

**Current location link**: Below search, show "Use current location" link text (14px, blue) with my_location icon on left.

**Map preview**: Rounded container (12px, 180px height) showing static map with location pin marker centered. If no location selected: grey placeholder (#E5E7EB) with map icon (40px, grey) and text "Search for an address to see the map". If location selected: show map image with blue pin marker centered, white semi-transparent label at bottom showing "City, State" with location icon.

**Address form fields** (two-column layout where appropriate):
- Street Address (full width)
- City | State/Province (50/50 split)
- Zip/Postal | Country dropdown (50/50 split)

All fields: white rounded inputs (12px), grey borders, blue focus borders. Country field is dropdown with down arrow icon.

Light grey background. Bottom bar with "Back" and "Next" buttons.

---

## 6. CONTACT INFORMATION (Step 5 of 6)

**Prompt:**
Design a business contact information form. Top shows "Step 5 of 6" and 83% blue progress bar. Heading: "How can customers reach you?" (28px, bold, black). Subtitle: "Add your business contact info so clients can easily get in touch with you" (15px, grey).

**Required Contact Section**:
1. **Business Phone**: Label "Business Phone" with red asterisk. Two-part input:
   - Left: Country code picker button (white, rounded 12px, shows flag emoji, country code like "+91", down arrow icon)
   - Right: Phone number input field (white, rounded 12px, phone icon left, placeholder "000 000 0000")

2. **Business Email**: Label "Business Email", white rounded input with email icon, placeholder "contact@yourbusiness.com"

3. **Website**: Label "Website", white rounded input with globe icon, placeholder "https://www.yourbusiness.com"

**Social Profiles Section** (with "Optional" grey badge):
- Section header: "Social Profiles" (14px, bold, grey) with small grey rounded badge "Optional" next to it
- Four social input fields (12px spacing between):
  - Instagram: camera icon, placeholder "Instagram username"
  - Facebook: Facebook icon, placeholder "Facebook profile URL"
  - Twitter/X: Bold 𝕏 character as icon, placeholder "Twitter/X handle"
  - WhatsApp: phone icon, placeholder "WhatsApp number"

All inputs: white, rounded 12px, grey border, blue focus, icon on left, grey placeholder text.

Light grey background. Bottom bar with "Back" and "Next" buttons.

---

## 7. COUNTRY CODE PICKER MODAL

**Prompt:**
Design a bottom sheet modal for country selection. Modal slides up from bottom, rounded top corners (20px), white background. Small grey handle bar at very top (40px wide, 4px tall, grey, centered). Title "Select Country" (18px, bold, grey-black, centered, 16px padding).

Below title: search input field with grey background (#F3F4F6), rounded 12px, no border, search icon left, placeholder "Search country...".

Below search: scrollable list of countries (take up ~70% of screen height). Each country item is a ListTile: flag emoji (24px) on left, country name (black text, medium weight), country code (right side, grey text, or blue if selected). Selected item has light blue background (#EFF6FF) and blue text for code. Tap anywhere on row to select.

Show countries: United States 🇺🇸 (+1), Canada 🇨🇦 (+1), United Kingdom 🇬🇧 (+44), India 🇮🇳 (+91), Australia 🇦🇺 (+61), Germany 🇩🇪 (+49), France 🇫🇷 (+33), Japan 🇯🇵 (+81), China 🇨🇳 (+86), Brazil 🇧🇷 (+55), and more (40+ countries total).

White background, subtle scroll indicator.

---

## 8. REVIEW & CONFIRMATION (Step 6 of 6)

**Prompt:**
Design a profile review and confirmation screen. Top shows "Step 6 of 6" and 100% blue progress bar. Top navigation: back arrow icon (left), "Review Details" text (16px, bold, black), "Final Review" text (right, 14px, grey).

Main heading: "Review your business profile" (24px, bold, black). Subtitle: "Please verify your information below" (15px, grey).

**Review sections** (vertical stack, 16px gaps between sections):

Each section is a white rounded container (12px) with grey border, 16px padding:

1. **Business Identity section**:
   - Header row: blue icon (business/store), "Business Identity" text (15px, bold), "Edit" link (blue, right-aligned)
   - Below: key-value pairs in two columns:
     - "Name" | "Joe's Coffee Shop"
     - "Description" | "Legal name here"

2. **Logo Preview section**:
   - Header: image icon, "Logo Preview", "Edit" link
   - Center-aligned: rounded square container (80px) showing uploaded logo, or grey placeholder with store icon if no logo

3. **Type & Category section**:
   - Header: category icon, "Type & Category", "Edit" link
   - "Type" | "Food & Beverage"
   - "Category" | "Cafe"

4. **Location section**:
   - Header: location icon, "Location", "Edit" link
   - "Address" | "123 Main St"
   - "City" | "New York, NY"

5. **Contact section**:
   - Header: phone icon, "Contact", "Edit" link
   - "Phone" | "+91 9876543210"
   - "Email" | "contact@example.com"
   - "Website" | "www.example.com"

At bottom: Checkbox (blue when checked) with text "I accept the Terms of Service and Privacy Policy" (Terms and Privacy are blue underlined links).

Light grey background. Bottom bar with "Back" (outlined) and "Complete Setup" button (blue, solid) with checkmark icon. Button disabled (grey) if terms not accepted.

---

## 9. BUSINESS DASHBOARD - HOME TAB

**Prompt:**
Design a modern business dashboard home screen. Top app bar: white background, "Dashboard" title (20px, bold, black, left), notification bell icon (right, with red dot badge if notifications exist).

Below app bar: White rounded card (16px padding, 12px radius, subtle shadow) showing business header:
- Left: circular logo (60px diameter) or grey placeholder
- Right side (column): Business name "Joe's Coffee Shop" (18px, bold, black), category badge below (blue rounded pill, small text "Cafe • Food & Beverage"), location text with pin icon (14px, grey).

**Stats Grid** (titled "Today's Kitchen" or category-appropriate title, 16px bold):
2×2 grid of stat cards (12px gaps). Each card: white, rounded 12px, subtle border, 16px padding:
- Icon in color (top, 24px): orders (green), revenue (blue), preparing (orange), delivery (purple)
- Large number below (24px, bold, black): "12", "₹5.2K", "8", "4"
- Label text below number (13px, grey): "Orders", "Revenue", "Preparing", "Delivery"

**Quick Actions** (section title 16px bold, 20px top margin):
3 horizontal action cards (12px gaps):
- White rounded containers (12px), icon (32px, colored), title (15px, bold), subtitle (13px, grey)
- "Orders" (green icon, receipt) | "View & manage orders"
- "Menu" (orange icon, restaurant menu) | "Edit menu items"
- "Tables" (blue icon, table) | "Manage reservations"

**Recent Activity** (section title, 20px top margin):
List of 3-4 recent items (white cards, 12px rounded, 12px vertical padding):
- Icon left (order, customer, notification icon), main text (14px, black), time text (12px, grey, right), right arrow icon

Bottom: Navigation bar with 4 tabs: Home (active/blue), Messages, Profile, More.

Background: light grey (#F9FAFB).

---

## 10. BUSINESS DASHBOARD - FOOD & BEVERAGE VARIANT

**Prompt:**
Design the same dashboard layout as #9, but customize for restaurants/cafes:
- Stats section titled "Today's Kitchen" showing: Orders (receipt icon, green), Revenue (rupee icon, blue), Preparing (restaurant icon, orange), Delivery (delivery bike icon, purple)
- Quick Actions show: Orders (receipt icon), Menu (menu icon), Tables (table icon)
- Stats show specific numbers like "28 Orders", "₹15.4K Revenue", "12 Preparing", "6 Delivery"

Same white cards, blue accent color, clean modern design, light grey background.

---

## 11. BUSINESS DASHBOARD - RETAIL/GROCERY VARIANT

**Prompt:**
Design business dashboard for retail stores:
- Header same as #9
- Stats section titled "Store Overview": Orders (shopping bag, green), Revenue (rupee, blue), Low Stock (warning, red), In Stock (inventory, green)
- Display: "15 Orders", "₹8.2K Revenue", "3 Low Stock", "145 In Stock"
- Quick Actions: Orders (shopping bag icon), Products (inventory icon), Add Product (plus icon)

Same clean layout, white cards, rounded corners, light grey background.

---

## 12. BUSINESS DASHBOARD - HOSPITALITY (HOTEL) VARIANT

**Prompt:**
Design business dashboard for hotels/hospitality:
- Stats section titled "Property Status": Check-ins (login icon, green), Check-outs (logout icon, orange), Available (hotel icon, blue), Bookings (calendar icon, purple)
- Display: "8 Check-ins", "5 Check-outs", "24/50 Available", "12 Bookings"
- Quick Actions: Bookings (calendar), Rooms (hotel icon), Check-ins (login icon)

Same design system, light grey background, white cards.

---

## 13. BUSINESS DASHBOARD - SERVICES (BEAUTY/HEALTHCARE) VARIANT

**Prompt:**
Design business dashboard for service businesses (salons, clinics):
- Stats section titled "Today's Snapshot": Appointments (calendar, green), Inquiries (chat bubble, orange), Completed (checkmark, blue), Revenue (rupee, green)
- Display: "18 Appointments", "7 Inquiries", "15 Completed", "₹12.3K Revenue"
- Quick Actions: Appointments (calendar icon), Services (tools icon), Clients (people icon)

Same clean modern design, white rounded cards, blue accents.

---

## 14. BUSINESS DASHBOARD - FITNESS VARIANT

**Prompt:**
Design business dashboard for gyms/fitness centers:
- Stats section titled "Today's Activity": Classes (dumbbell, green), Check-ins (people, blue), Bookings (event, orange), Revenue (rupee, green)
- Display: "12 Classes", "64 Check-ins", "8 Bookings", "₹25.6K Revenue"
- Quick Actions: Classes (fitness icon), Members (membership card), Trainers (sports icon)

Same layout as others, white cards on light grey, blue accent theme.

---

## 15. BUSINESS DASHBOARD - EDUCATION VARIANT

**Prompt:**
Design business dashboard for schools/education:
- Stats section titled "Today's Schedule": Classes (school, green), Attendance (people, blue), Inquiries (chat, orange), Revenue (rupee, green)
- Display: "15 Classes", "145 Attendance", "5 Inquiries", "₹45.2K Revenue"
- Quick Actions: Classes (school icon), Students (people icon), Courses (book icon)

Modern clean design, consistent with other dashboards.

---

## 16. MENU MANAGEMENT SCREEN (FOOD & BEVERAGE)

**Prompt:**
Design a menu management screen for restaurants. Top app bar: "Menu" title (20px, bold), search icon (right), add (+) icon (far right, blue).

**Category tabs**: Horizontal scrollable tab bar below header (white background): All, Appetizers, Main Course, Desserts, Beverages, Specials. Active tab has blue underline (3px), inactive tabs are grey text.

**Menu items list**: Vertical scrolling list of menu items (white cards, 12px rounded, 12px gaps):
Each card shows:
- Left: Square food image (80×80px, rounded 8px) or grey placeholder with utensils icon
- Middle (column): Item name (16px, bold, black), description text (13px, grey, 2 lines max, truncated), price "₹250" (14px, bold, blue)
- Right: Three-dot menu icon (vertical) for Edit/Delete options
- Bottom of card: Small badges showing "Veg" (green) / "Non-Veg" (red), "Popular" badge if applicable (orange)

**Category headers**: Sticky headers between sections showing category name (14px, bold, grey, with category icon).

Floating action button (FAB) at bottom right: Large blue circular button (+) with subtle shadow.

Light grey background. Bottom shows count "45 items" (12px, grey, centered).

---

## 17. MENU ITEM ADD/EDIT FORM (FOOD & BEVERAGE)

**Prompt:**
Design a menu item creation form screen. Top app bar: back arrow (left), "Add Menu Item" title (18px, bold), save checkmark icon (right, blue).

Scrollable form with white background:

1. **Photo Upload Section**: Large rounded container (12px, grey dashed border) for item photo. If empty: camera icon (48px, grey), text "Add item photo" (14px, grey), subtext "Tap to upload" (12px, light grey). If uploaded: show image with edit icon overlay in corner.

2. **Basic Info Section**:
   - Item Name* field (white input, rounded)
   - Description field (white input, rounded, multiline, 3 rows)
   - Category dropdown (white, rounded, down arrow): Appetizers, Main Course, Desserts, etc.

3. **Pricing Section**:
   - Price* field (rupee icon prefix, number input)
   - Discount % field (optional, percentage icon)
   - Final Price shown in blue text if discount applied

4. **Tags Section**: "Food Type" chips (multi-select): Veg (green when selected), Non-Veg (red when selected), Vegan (green), Gluten-Free (orange)

5. **Availability Toggle**: Switch toggle (blue when on) with label "Available for orders"

6. **Additional Options**:
   - "Mark as Popular" checkbox (with star icon)
   - "Recommended" checkbox

Bottom fixed white bar (shadow): "Cancel" (grey text button) and "Save Item" (blue solid button).

Light grey background, 20px padding, 16px gaps between sections.

---

## 18. ORDERS SCREEN (FOOD & BEVERAGE)

**Prompt:**
Design an orders management screen. Top app bar: "Orders" title (20px, bold), filter icon (right), refresh icon (far right).

**Status filter tabs**: Horizontal tabs below header: All, Pending (with orange badge "12"), Preparing (green badge "8"), Ready (blue badge "5"), Delivered (grey).

**Orders list**: Vertical scrolling list of order cards (white, rounded 12px, 16px padding, 12px gaps):
Each order card shows:
- Top row: Order number "ORD-1234" (16px, bold, left), status badge (right) - color-coded pill: "Pending" (orange), "Preparing" (green), "Ready" (blue), "Delivered" (grey)
- Customer name with person icon (14px, grey)
- Order items: "2x Cappuccino, 1x Sandwich..." (14px, grey, truncated)
- Time "15 mins ago" (12px, grey, left), Total amount "₹450" (16px, bold, blue, right)
- Bottom row: Two action buttons: "View Details" (outlined, grey) and "Accept" / "Mark Ready" (solid, status-specific color)

**Empty state**: If no orders: Center screen showing empty box icon (64px, grey), "No orders yet" text (18px, grey), "Orders will appear here" subtext (14px, light grey).

Floating action button (FAB) bottom right: "+" icon to create manual order.

Light grey background. Pull-to-refresh indicator at top.

---

## 19. PRODUCTS SCREEN (RETAIL)

**Prompt:**
Design a product inventory screen. Top app bar: "Products" title (20px, bold), search icon, filter icon, add (+) icon (blue).

**Filter chips**: Horizontal scrollable row of filter chips below header: All Products, In Stock (green), Low Stock (orange), Out of Stock (red). Selected chip has solid color background, unselected has outline only.

**Products grid**: 2-column grid of product cards (12px gaps):
Each card: white background, rounded 12px, no padding:
- Product image top (full width, 160px height, rounded top corners) or grey placeholder
- Below image: 12px padding section with:
  - Product name (14px, bold, black, 2 lines max)
  - SKU number (11px, grey) "SKU: P12345"
  - Price (16px, bold, blue) "₹999"
  - Stock badge: "In Stock" (green pill), "Low Stock" (orange pill, shows "5 left"), "Out of Stock" (red pill)
- Bottom row: edit icon and delete icon (grey, small)

**Bulk actions bar** (appears when items selected): Fixed bottom bar (white, shadow) showing: "2 items selected" (left), "Delete" button (red, text), "Edit" button (blue, text).

Light grey background. Show count "124 products" at bottom (12px, grey, centered).

---

## 20. PRODUCT ADD/EDIT FORM (RETAIL)

**Prompt:**
Design product creation form. Top app bar: back arrow, "Add Product" title, save icon (blue).

Scrollable white form:

1. **Product Images**: Horizontal scrollable row of image slots (100×100px squares, rounded 8px):
   - First slot: "+" icon with "Add photos" text (grey dashed border)
   - Subsequent slots show uploaded images with small X delete icon in corner
   - Max 5 images

2. **Basic Information**:
   - Product Name* (input field)
   - Category dropdown (Clothing, Electronics, Home & Living, etc.)
   - Brand name (input field)
   - SKU/Barcode (input with scan icon button on right)

3. **Description**: Multiline text field (4 rows) with character counter "0/500"

4. **Pricing**:
   - Regular Price* (rupee icon prefix)
   - Sale Price (optional)
   - Cost Price (optional, with lock icon - "for your records only" helper text)

5. **Inventory**:
   - Stock Quantity* (number input with +/- stepper buttons)
   - Low Stock Alert (number input, default 5)
   - Toggle: "Track inventory" (blue when on)

6. **Variants** (optional, collapsible section):
   - "Add variants" button (outlined)
   - If added: Size (S, M, L, XL chips), Color (color circle selectors)

7. **Product Tags**: Free text input with suggestions: Popular, New Arrival, Bestseller, Sale, Featured

Bottom bar: "Cancel" and "Save Product" buttons.

Light grey background, 20px padding.

---

## 21. ROOMS SCREEN (HOSPITALITY)

**Prompt:**
Design hotel rooms management screen. Top app bar: "Rooms" title, search icon, filter icon, add (+) icon.

**Room Type Cards**: Vertical list of room type cards (white, rounded 12px, shadow, 16px padding, 16px gaps):
Each card shows:
- Left section: Room photo (100×100px, rounded 8px) or hotel icon placeholder
- Middle section (column):
  - Room type name "Deluxe Suite" (16px, bold, black)
  - Amenities icons row: WiFi, AC, TV icons (small, grey)
  - Occupancy "2 Adults, 1 Child" with person icons (13px, grey)
- Right section (column, right-aligned):
  - Price per night "₹3,500/night" (16px, bold, blue)
  - Availability status: "5 Available" (green text) or "Fully Booked" (red text)
  - Small availability bar (horizontal, showing 5/10 filled in blue)

Each card has edit and delete icons in top-right corner.

**Booking calendar view toggle**: Toggle button top-right to switch between "List View" and "Calendar View".

Light grey background.

---

## 22. ROOM ADD/EDIT FORM (HOSPITALITY)

**Prompt:**
Design room type creation form. Top bar: back arrow, "Add Room Type" title, save icon.

White background form:

1. **Room Images**: Similar to product images - horizontal scrollable row, 5 max

2. **Room Details**:
   - Room Type Name* (Deluxe, Suite, Standard, etc.)
   - Room Category dropdown
   - Room Numbers input (e.g., "101-105, 201-205") with helper text

3. **Capacity**:
   - Adults* (number input with stepper)
   - Children (number input with stepper)
   - Extra Bed Available (toggle switch)

4. **Pricing**:
   - Base Price per Night* (rupee icon)
   - Weekend Price (optional, +20% badge suggestion)
   - Extra Person Charge (rupee icon)

5. **Room Size**: Square footage input with "sq ft" suffix

6. **Amenities** (multi-select chips): WiFi, AC, TV, Mini Bar, Balcony, Sea View, Bathtub, Room Service, Safe, Coffee Maker. Selected chips are blue, unselected are outlined grey.

7. **Description**: Multiline text area (3 rows)

8. **Availability Toggle**: "Available for booking" switch (blue when on)

Bottom bar: "Cancel" and "Save Room Type" buttons.

---

## 23. BOOKINGS CALENDAR SCREEN (HOSPITALITY)

**Prompt:**
Design a hotel bookings calendar view. Top app bar: "Bookings" title, calendar icon, filter icon.

**Date Navigation**: Below header, horizontal date selector showing week view:
- Previous/Next week arrows on ends
- 7 date boxes showing: "Mon 15", "Tue 16", "Wed 17" (today highlighted in blue pill)

**Room Timeline**: Vertical list of rooms (left labels) with horizontal timeline (Gantt-chart style):
- Left column: Room numbers "101", "102", "103", etc. (fixed width, grey background)
- Right area: Scrollable horizontal timeline showing bookings as colored blocks
- Each booking block: Color-coded (confirmed=green, pending=orange, checked-in=blue), shows guest name, spans multiple columns (days)
- Empty slots show as white/light grey
- Time slots divided by day columns with light vertical dividers

**Booking blocks**: When tapped, show popup with guest details, check-in/out dates, booking status.

**Legend**: Bottom sticky bar showing color codes: Green (Confirmed), Orange (Pending), Blue (Checked In), Grey (Checked Out).

White background, grid lines in light grey.

---

## 24. APPOINTMENTS SCREEN (SERVICES)

**Prompt:**
Design appointments management screen. Top app bar: "Appointments" title, calendar icon (view toggle), add (+) icon.

**Date selector**: Horizontal scrollable date chips below header:
- Today (blue pill, bold), Tomorrow, dates for next 7 days
- Selected date is solid blue, others are outlined

**Time slots view**: Vertical timeline showing appointment slots:
- Left: Time labels (9:00 AM, 10:00 AM, 11:00 AM, etc.) in grey
- Right: Appointment cards in time slots

**Appointment cards** (white, rounded 8px, colored left border - green for confirmed, orange for pending):
- Customer name (16px, bold) with person icon
- Service name (14px, grey) with service icon
- Time range "10:00 AM - 11:00 AM" (13px, grey)
- Price "₹1,200" (14px, blue, right-aligned)
- Bottom row: "Call" icon button, "Reschedule" button, "Complete" button (green)

**Empty slots**: Show as dashed outline boxes with "+ Add appointment" text (grey).

**Filter tabs** top: All, Upcoming, Completed, Cancelled.

Light grey background.

---

## 25. APPOINTMENT BOOKING FORM (SERVICES)

**Prompt:**
Design appointment creation form. Top bar: back arrow, "New Appointment" title, save icon.

White background form:

1. **Customer Selection**:
   - Search/Select existing customer (searchable dropdown with person icons)
   - Or "Add new customer" link (blue)

2. **Service Selection** (multi-select):
   - List of services with checkboxes:
     - Service name (16px, bold)
     - Duration (13px, grey) "45 mins"
     - Price (14px, blue) "₹800"
   - Selected services show checkmark and blue border

3. **Staff/Provider**: Dropdown showing staff members with profile photos (30px circle), name, specialty

4. **Date & Time**:
   - Date picker (calendar icon, shows selected date)
   - Time slot selector: Grid of time slots (30-min intervals) showing "9:00", "9:30", "10:00", etc.
   - Available slots: white outline, selected: blue solid, unavailable: grey disabled

5. **Total Summary Card**: Blue-tinted card showing:
   - Services list
   - Total Duration "1h 30mins"
   - Total Price "₹1,500"

6. **Notes** (optional): Multiline text field for appointment notes

7. **Send Confirmation**: Toggle switch "Send SMS/Email confirmation to customer"

Bottom bar: "Cancel" and "Book Appointment" (blue solid) buttons.

---

## 26. CLASSES SCHEDULE SCREEN (FITNESS/EDUCATION)

**Prompt:**
Design classes schedule screen. Top app bar: "Classes" title, calendar view icon, add (+) icon.

**Week View Tabs**: Horizontal tabs showing: Mon, Tue, Wed (today - blue), Thu, Fri, Sat, Sun.

**Classes Timeline**: Vertical list of class cards for selected day:

Each class card (white, rounded 12px, 16px padding, 12px gaps):
- Top row: Class time "6:00 AM - 7:00 AM" (14px, bold, left), status badge (right) - "Scheduled" (blue), "Ongoing" (green), "Completed" (grey)
- Class name "Power Yoga" (18px, bold, black)
- Instructor name with profile photo (30px circle) "by Sarah Johnson" (14px, grey)
- Attendees: Row of overlapping profile photos (4 shown, "+12 more" text) with capacity "16/20 joined" (13px, grey)
- Location/Room: Icon with "Studio A" text (13px, grey)
- Bottom row: "View Attendees" link (blue), "Mark Attendance" button (outlined), "Cancel Class" (red text)

**Filter row** at top: Chips for "All Classes", "Yoga", "Zumba", "Cardio", "Strength Training" (horizontal scroll).

**Empty state**: If no classes: Calendar icon, "No classes scheduled" text, "Add your first class" button (blue).

Light grey background.

---

## 27. CLASS ADD/EDIT FORM (FITNESS/EDUCATION)

**Prompt:**
Design class creation form. Top bar: back arrow, "Add Class" title, save icon.

White background form:

1. **Class Type**: Dropdown or chips for class categories (Yoga, Zumba, Cardio, etc.)

2. **Class Name***: Text input "e.g., Morning Power Yoga"

3. **Instructor**: Dropdown with instructor profiles (photo, name, specialization)

4. **Schedule**:
   - Recurrence type: Radio buttons for "One-time", "Daily", "Weekly", "Custom"
   - Date picker (if one-time) or day selector (if recurring) - chips for Mon, Tue, Wed, etc.
   - Start Time & End Time (time pickers with clock icons)
   - Duration calculated automatically "60 minutes" (blue text)

5. **Location/Room**: Dropdown or text input "Studio A"

6. **Capacity**:
   - Max Participants (number input with stepper)
   - Waiting List toggle (blue switch)

7. **Pricing** (if applicable):
   - Drop-in Price (rupee icon)
   - "Included in membership" checkbox

8. **Description**: Multiline text area for class details

9. **Requirements/Notes**: Text area for "Bring yoga mat, water bottle"

Bottom bar: "Cancel" and "Create Class" buttons.

---

## 28. MEMBERS/CUSTOMERS SCREEN

**Prompt:**
Design members/customers list screen. Top app bar: "Members" title (or "Customers"), search icon, filter icon, add (+) icon.

**Membership filter tabs** (if fitness): All, Active (green badge), Expired (orange), Trial (blue).

**Search bar**: Below tabs, white rounded search input with search icon, placeholder "Search by name, phone, email..."

**Members List**: Vertical scrolling list of member cards (white, rounded 12px, 16px padding, 12px gaps):

Each card shows:
- Left: Profile photo (50px circle) or grey circle with initials
- Middle section (column):
  - Member name (16px, bold, black)
  - Membership type "Gold Member" or customer type (13px, blue)
  - Contact: phone number with phone icon (13px, grey)
  - Join date / Last visit "Last visit: 2 days ago" (12px, light grey)
- Right section:
  - Status badge: "Active" (green pill), "Expired" (red pill), "Trial" (blue pill)
  - Membership end date if applicable "Expires: Dec 31" (11px, grey)

Bottom action row per card: "Call" icon, "Message" icon, "View Profile" text link (blue), three-dot menu (Edit/Delete).

**Quick stats header**: Before list, card showing "Total Members: 234", "Active: 189", "Expiring Soon: 12" (icon + number format).

Light grey background. Floating action button (+) for adding new member.

---

## 29. MEMBER/CUSTOMER PROFILE VIEW

**Prompt:**
Design detailed member profile screen. Top bar: back arrow, "Member Profile" title, edit icon, three-dot menu.

**Profile Header Card** (white, rounded 12px, gradient background top):
- Center: Large profile photo (100px circle) or grey placeholder with camera edit icon overlay
- Below: Member name (22px, bold, black)
- Member ID "#M12345" (13px, grey)
- Membership type badge "Gold Member" (blue pill)
- Join date "Member since Jan 2023" (13px, grey)

**Contact Section**: White card with icon rows:
- Phone: phone icon, number, "Call" button (outlined, blue)
- Email: email icon, address, "Email" button
- WhatsApp: WhatsApp icon, number, "Chat" button (green)

**Membership Details** (if applicable): White card:
- Plan name "Gold Annual Plan" (16px, bold)
- Start date | End date (two columns)
- Status: Progress bar showing time remaining, "85 days left" (blue)
- Auto-renewal toggle (on/off)

**Activity/History Section**: List of activity cards:
- Recent visits with timestamps
- Classes attended / Products purchased
- Total revenue "₹45,000" (blue, bold)

**Notes Section**: Text area showing staff notes about the member (editable if staff).

Bottom fixed bar: "Renew Membership" (blue button) or "Send Message" (outlined button).

Light grey background, sections spaced 16px apart.

---

## 30. ANALYTICS SCREEN

**Prompt:**
Design business analytics dashboard. Top app bar: "Analytics" title, date range selector "Last 30 days" (dropdown), share icon.

**Revenue Card** (large, prominent, blue gradient):
- Icon: rupee symbol in circle
- "Total Revenue" label (16px, white/light)
- Large number "₹1,24,500" (32px, bold, white)
- Percentage change "+15.3% vs last month" (14px, green/white) with up arrow
- Mini line chart showing trend (white line)

**Key Metrics Grid** (2×2):
Each card: white, rounded 12px, 16px padding, shadow:
- Small icon in color circle (top left)
- Metric value "245" (24px, bold, black)
- Metric label "Total Orders" (14px, grey)
- Change indicator "+12%" (green) or "-5%" (red) with small arrow

Metrics: Total Orders (shopping bag, green), New Customers (person, blue), Avg Order Value (rupee, orange), Return Rate (refresh, purple).

**Charts Section**:

1. **Revenue Trend Chart**: Line chart card (white) showing revenue over time (last 30 days):
   - X-axis: dates, Y-axis: revenue amounts
   - Blue line with gradient fill below
   - Hover shows tooltip with exact values

2. **Top Products/Services**: Horizontal bar chart card:
   - List of top 5 items with horizontal bars
   - Item name, bar (blue), value "₹12,345" (right)
   - Sorted by revenue

3. **Customer Demographics**: Pie chart or donut chart:
   - Segments: New vs Returning (color-coded)
   - Legend with percentages

4. **Hourly Sales Pattern**: Column chart showing sales by hour (9 AM - 9 PM)

**Export Section**: Button "Download Report" (outlined, blue) at bottom.

Light grey background, charts use blue color scheme.

---

## 31. MESSAGES/CONVERSATIONS SCREEN

**Prompt:**
Design business messaging screen. Top app bar: "Messages" title, search icon, filter icon.

**Tabs**: All (with unread badge "5"), Unread, Archived.

**Conversations List**: Vertical scrolling list of conversation cards (white, tap-able):

Each conversation item (16px vertical padding, divider line):
- Left: Customer profile photo (50px circle) or grey placeholder
- Middle section (expanding, column):
  - Customer name (16px, bold, black)
  - Last message preview (14px, grey, truncated to 1 line) "Thanks for the quick response..."
  - Time "2:30 PM" or "Yesterday" (12px, grey, right-aligned on same line as preview)
- Right: Blue unread badge "2" (circle) if unread messages exist

**Visual states**:
- Unread: bold name, blue dot indicator, white background
- Read: normal weight name, no dot, white background
- Active conversation: light blue background tint

**Quick reply**: Long-press conversation shows quick action menu: Archive, Delete, Mark as Unread, Block.

**Empty state**: If no conversations: Chat bubble icon (64px, grey), "No messages yet" text, "Start a conversation" button.

Light grey background. Floating action button (+) to start new conversation.

---

## 32. CHAT/CONVERSATION VIEW

**Prompt:**
Design 1-on-1 chat interface. Top app bar: back arrow, customer profile photo (40px circle), customer name (18px, bold), "Online" status (green dot), phone call icon, video call icon, three-dot menu.

**Messages Area**: Scrollable chat messages (light grey background):

**Received messages** (left-aligned):
- Grey rounded bubble (18px radius, sharp corner bottom-left)
- Black text (15px)
- Timestamp below "2:30 PM" (11px, grey)
- Profile photo (30px) on left (only for first message in group)

**Sent messages** (right-aligned):
- Blue gradient rounded bubble (sharp corner bottom-right)
- White text (15px)
- Timestamp below right-aligned (11px, light grey)
- Double checkmark (read) or single checkmark (sent) next to time

**Date separators**: "Today", "Yesterday" in grey chips (centered) between message groups.

**Typing indicator**: Grey bubble with three animated dots when other person is typing.

**Message Input Bar** (bottom, white, shadow):
- Left: Attachment icon (paperclip), camera icon
- Center: Expandable text input field (white, rounded pill, grey border) placeholder "Type a message..."
- Right: Send button (blue circle with paper plane icon) - only shows when text entered, otherwise show microphone icon

**Quick Replies** (if business has pre-defined): Horizontal scrollable chips above input: "Yes, available", "Open at 9 AM", "Will call you back".

White/light grey background for chat area.

---

## 33. BUSINESS PROFILE TAB - VIEW MODE

**Prompt:**
Design business profile public view screen. Top: Cover image (full width, 200px height, blue gradient overlay) or default gradient.

**Profile Header** (overlapping cover):
- Center: Business logo (100px circle, white border, shadow) positioned half on cover, half on content
- Below: Business name "Joe's Coffee Shop" (22px, bold, black, centered)
- Category badge "Cafe • Food & Beverage" (blue pill, centered)
- Rating: 4.5 stars (gold) with "(234 reviews)" grey text
- Location: pin icon + "Downtown, New York" (14px, grey)
- Status: "Open Now" (green text) or "Closed" (red) with hours "Opens at 9:00 AM"

**Action Buttons Row** (4 buttons, horizontal, equal width):
- Call (phone icon, outlined)
- Message (chat icon, outlined)
- Direction (navigation icon, outlined)
- Share (share icon, outlined)

**Verified Badge**: If verified, show blue checkmark badge next to name.

**Stats Row**: Horizontal (equal width, centered):
- "234" Reviews (star icon)
- "1.2K" Followers (heart icon)
- "95%" Response (clock icon)

**About Section**: White card (16px padding):
- "About" header (16px, bold)
- Description text (14px, grey, 4 lines, "Read more" link if longer)
- Business hours: Collapsible section showing Mon-Sun timings with open/closed status
- Website link (blue, underlined) with globe icon
- Social media icons: Instagram, Facebook, Twitter (row of icon buttons)

**Sections** (tabs or scrollable):
- Menu/Products (grid view with images)
- Services (list with icons)
- Gallery (image grid 3×3)
- Reviews (star ratings + text)
- Location (map embed)

Floating action button: "Edit Profile" (blue, pencil icon) if owner viewing.

Light grey background, white section cards.

---

## 34. BUSINESS PROFILE TAB - EDIT MODE

**Prompt:**
Design business profile edit screen. Top app bar: back arrow, "Edit Profile" title, save icon (blue).

Scrollable form on white background:

1. **Cover & Logo Section**:
   - Cover image area (full width, 200px) with camera icon overlay "Change cover"
   - Logo (100px circle) with camera icon "Change logo"

2. **Basic Info**:
   - Business Name (text input)
   - Legal Name (text input)
   - Category (dropdown, disabled/grey - "Can't be changed")
   - Bio/Description (multiline, 4 rows, character counter "150/500")

3. **Contact Information**:
   - Phone (with country code picker)
   - Email
   - Website
   - WhatsApp Business

4. **Social Profiles**:
   - Instagram handle
   - Facebook URL
   - Twitter handle

5. **Business Hours**: Collapsible section:
   - Each day row: "Monday" | toggle switch (Open/Closed) | time pickers "9:00 AM - 6:00 PM"
   - "Copy to all days" link (blue)
   - "Open 24/7" checkbox

6. **Address**: "Edit" link opens location picker (from onboarding step 4)

7. **Services/Specialties**: Multi-select chips showing business specialties

8. **Additional Info**:
   - Founded year
   - Team size
   - Languages spoken (multi-select)
   - Payment methods accepted (chips: Cash, Card, UPI, etc.)

Bottom bar: "Cancel" (grey text) and "Save Changes" (blue solid) buttons.

---

## 35. GALLERY MANAGEMENT SCREEN

**Prompt:**
Design business gallery screen. Top app bar: "Gallery" title, select icon (checkbox mode), add (+) icon.

**Filter tabs**: All, Cover Photos, Products, Interior, Team, Events.

**Photo Grid**: Pinterest-style masonry grid or uniform 3-column grid:
- Each photo: Rounded corners (8px), tap to view full size
- Hover/long-press shows overlay with: Set as Cover, Edit, Delete icons
- Selected photos (in select mode) show blue checkmark overlay

**Photo Card Actions** (on long-press):
- Add Caption
- Set as Featured
- Set as Cover Image
- Move to Album
- Delete

**Upload Options** (+ button menu):
- Take Photo
- Choose from Gallery
- Choose Multiple (up to 10)

**Photo View Modal** (when photo tapped):
- Full-screen image viewer
- Swipe left/right to navigate
- Bottom bar: Caption text, date uploaded, view count
- Top bar: Back arrow, share icon, three-dot menu (Edit/Delete)

Light grey background. Show count "45 photos" at bottom.

---

## 36. REVIEWS & RATINGS SCREEN

**Prompt:**
Design reviews management screen. Top app bar: "Reviews" title, filter icon, sort icon.

**Rating Summary Card** (white, prominent):
- Left: Large rating number "4.5" (48px, bold, black)
- Star icons below (5 gold stars, partially filled for 4.5)
- "Based on 234 reviews" (14px, grey)
- Right: Rating breakdown (vertical bars):
  - 5 stars | horizontal bar (gold, 75% filled) | "180"
  - 4 stars | bar (60% filled) | "35"
  - 3 stars | bar (15% filled) | "12"
  - 2 stars | bar (5% filled) | "5"
  - 1 star | bar (2% filled) | "2"

**Filter/Sort Row**: Chips for "All", "5 Stars", "4 Stars", "With Photos", "Recent" (horizontal scroll).

**Reviews List**: Vertical scrolling cards (white, rounded 12px, 16px padding, 12px gaps):

Each review card:
- Top row: Customer profile photo (40px circle) | Name (16px, bold) | Date "2 days ago" (right, 12px, grey)
- Star rating (5 gold stars) below name
- Review text (14px, grey, 4 lines max, "Read more" if longer)
- If photos attached: Horizontal scrollable row of thumbnail photos (80×80px, rounded 8px)
- Bottom row: "Helpful (12)" with thumbs up icon (grey button), "Reply" button (outlined, blue)
- If you've replied: Show your reply in indented light blue card below

**Response Card** (if business replied):
- Indented with left blue border (4px)
- "Response from Owner" label (12px, bold)
- Response text (14px, black)
- Date replied (11px, grey)

**Empty state**: No reviews yet - star icon, "No reviews yet" text, "Share profile to get reviews" suggestion.

Light grey background.

---

## 37. REVIEW REPLY MODAL

**Prompt:**
Design review reply modal. Bottom sheet slides up (white, rounded top 20px, handle bar at top).

**Header**: "Reply to Review" (18px, bold, centered), X close button (top right).

**Original Review Summary**:
- Customer name + rating stars (4 gold stars)
- Review text (2 lines, truncated, grey background card)

**Reply Input**:
- Label "Your Response" (14px, bold, grey)
- Multiline text area (white, rounded 12px, grey border, 4 rows, focus border blue)
- Character counter "0/500" (12px, grey, right-aligned)

**Tone Suggestions** (optional, collapsed by default):
- "Need help writing?" link to expand
- When expanded: Quick templates chips: "Thank you for feedback", "We'll improve", "Glad you enjoyed" (tap to insert)

**Preview**: Toggle to see how reply will appear publicly.

Bottom bar: "Cancel" (text button, grey) and "Post Reply" (solid blue button).

---

## 38. SETTINGS SCREEN

**Prompt:**
Design business settings screen. Top app bar: back arrow, "Settings" title.

**Settings grouped by sections** (list of white cards with dividers):

**Account Section**:
- Profile Settings (arrow icon right)
- Business Information (arrow icon)
- Bank Account & Payments (arrow icon)

**App Settings**:
- Notifications (toggle switch right, blue when on)
- Language: "English" (current value right, arrow)
- Dark Mode (toggle switch)

**Business Operations**:
- Operating Hours (arrow icon)
- Holiday Calendar (arrow icon)
- Delivery/Service Areas (arrow icon)
- Tax & GST Settings (arrow icon)

**Customer Experience**:
- Auto-Reply Messages (toggle + arrow)
- Booking Settings (arrow)
- Cancellation Policy (arrow)

**Privacy & Security**:
- Privacy Settings (arrow)
- Blocked Customers (arrow)
- Data & Storage (arrow)

**Support**:
- Help Center (arrow)
- Contact Support (arrow)
- Submit Feedback (arrow)
- Rate App (arrow)

**About**:
- Terms of Service (arrow)
- Privacy Policy (arrow)
- App Version: "1.0.0" (grey text, no arrow)

**Danger Zone** (at bottom, red section):
- Deactivate Business (red text)
- Delete Account (red text)

Light grey background, each section is white card with grouped items.

---

## 39. NOTIFICATIONS SETTINGS

**Prompt:**
Design notifications settings screen. Top app bar: back arrow, "Notifications" title.

**General toggle**: At top, large toggle switch with:
- "Push Notifications" (18px, bold, left)
- "Receive all app notifications" (13px, grey, below)
- Toggle switch (right) - blue when on

**Notification Categories** (grouped sections, white cards):

**Orders & Bookings**:
- New Order (toggle)
- Order Confirmed (toggle)
- Order Cancelled (toggle)
- Booking Reminder (toggle)

**Customer Interactions**:
- New Message (toggle + sound icon)
- New Review (toggle)
- New Follower (toggle)
- Customer Check-in (toggle)

**Business Updates**:
- Low Stock Alert (toggle)
- Daily Summary (toggle + time picker "8:00 PM")
- Weekly Report (toggle + day picker "Monday")
- Payment Received (toggle)

**Marketing & Promotions**:
- Special Offers (toggle)
- Tips & Tutorials (toggle)
- Platform Updates (toggle)

Each toggle: Label (16px, black, left), description (13px, grey, below), toggle switch (right, blue when on).

**Sound & Vibration Section**:
- Notification Sound: "Default" (dropdown)
- Vibrate (toggle)
- LED Light (toggle)

Bottom: "Test Notification" button (outlined, blue) to send sample.

Light grey background.

---

## 40. BANK ACCOUNT & PAYMENTS SCREEN

**Prompt:**
Design bank account setup screen. Top app bar: back arrow, "Bank Account" title.

**Status Card** (top, if not set up):
- Warning icon (orange)
- "Bank account not added" (18px, bold, black)
- "Add your bank account to receive payments directly" (14px, grey)
- "Add Account" button (blue, solid)

If account exists:
- Checkmark icon (green)
- Bank name + account number (masked) "HDFC Bank ••••1234"
- "Verified" badge (green)
- "Change Account" button (outlined)

**Payment Methods Accepted**:
- Section header (16px, bold)
- Toggles for each: Cash (toggle), Cards (toggle), UPI (toggle), Net Banking (toggle), Digital Wallets (toggle)

**Payout Settings**:
- Auto Payout (toggle) - "Receive payments automatically"
- Payout Schedule: Dropdown - "Daily", "Weekly", "Monthly"
- Minimum Amount: "₹500" (input field)

**Transaction History** (list):
- Each row: Date, description "Payout for 12 orders", amount "₹15,400" (green), status "Success" (green)

**Bank Account Form** (if adding new):
- Account Holder Name*
- Account Number*
- Re-enter Account Number*
- IFSC Code*
- Bank Name (auto-filled from IFSC)
- Account Type: Radio buttons - Savings / Current

Bottom: "Save & Verify" button (blue) - triggers micro-deposit verification.

Light grey background, white cards.

---

## 41. SUPPORT/HELP CENTER SCREEN

**Prompt:**
Design help center screen. Top app bar: back arrow, "Help Center" title, search icon.

**Search Bar**: White rounded input, search icon left, placeholder "Search for help..."

**Quick Actions** (4 cards in 2×2 grid, rounded, with icons and labels):
- Chat with Support (chat icon, blue)
- Call Support (phone icon, green)
- Email Support (email icon, orange)
- FAQs (question icon, purple)

**Popular Topics** (section header):
List of topic cards (white, rounded, with arrow icons):
- Getting Started
- Managing Orders
- Payment Issues
- Profile & Settings
- Subscription & Billing
- Account Security

**FAQ Accordions** (collapsible):
Each FAQ: Question text (16px, bold, black) with down arrow icon. When tapped, expands to show answer text (14px, grey), collapses others.

Sample FAQs:
- "How do I add products to my catalog?"
- "How do I change my business hours?"
- "What payment methods are supported?"
- "How do I export reports?"

**Contact Information Card** (at bottom):
- Support Email: support@business.com (with copy icon)
- Phone: +1-800-123-4567 (with call button)
- Hours: Mon-Fri, 9 AM - 6 PM EST

**Feedback Section**: "Was this helpful?" with thumbs up/down icons.

Light grey background, white cards.

---

## 42. ERROR/OFFLINE STATE SCREENS

**Prompt:**
Design error and offline state screens.

**No Internet Connection**:
- Center screen content
- WiFi icon with slash (64px, grey)
- "No Internet Connection" heading (20px, bold, black)
- "Please check your connection and try again" text (14px, grey)
- "Retry" button (blue, solid, with refresh icon)

**Server Error (500)**:
- Broken server icon (64px, orange)
- "Something went wrong" heading
- "We're working to fix the issue" text
- "Try Again" button (blue)
- "Contact Support" link below (grey text, underlined)

**Not Found (404)**:
- Magnifying glass with X icon (64px, grey)
- "Page not found" heading
- "The page you're looking for doesn't exist" text
- "Go to Home" button (blue)

**Maintenance Mode**:
- Tools/wrench icon (64px, blue)
- "Under Maintenance" heading
- "We'll be back shortly" text with estimated time
- No action button, just informational

All states: centered content, minimal design, light grey or white background.

---

## 43. SUCCESS CONFIRMATION SCREENS

**Prompt:**
Design success confirmation screens.

**Profile Created Successfully**:
- Large checkmark icon in green circle (80px)
- "Profile Created!" heading (24px, bold, green)
- "Your business profile is now live" text (16px, grey)
- Preview card showing business profile snapshot
- "Go to Dashboard" button (green, solid)
- "Share Profile" button (outlined, green) below

**Order Placed Successfully**:
- Green checkmark icon (64px)
- "Order Confirmed!" heading
- Order number "#ORD-1234" (14px, grey)
- Estimated time "Ready in 30 mins" (16px, blue)
- "View Order Details" button (blue)

**Payment Successful**:
- Green checkmark icon
- "Payment Received" heading
- Amount "₹1,250" (large, green)
- Transaction ID (small, grey)
- "Download Receipt" button (outlined)
- "Done" button (solid, blue)

All success screens: white or light green tinted background, centered content, green accent color.

---

## 44. LOADING & SKELETON SCREENS

**Prompt:**
Design loading and skeleton state screens.

**Full Page Loading**:
- Center screen: Circular progress indicator (blue, rotating)
- App logo above (if applicable)
- "Loading..." text below (14px, grey)

**Skeleton Screens** (content placeholders while loading):

**Dashboard Skeleton**:
- Grey rounded rectangles (shimmer effect) matching layout:
  - Header card: logo circle, text lines
  - Stats grid: 4 cards with grey blocks
  - Quick actions: 3 cards with grey shapes
- Shimmer animation: light to dark grey wave moving left to right

**List Skeleton** (Orders, Products, etc.):
- Repeated card shapes:
  - Left circle (for image/avatar)
  - Right side: multiple horizontal grey lines (varying widths)
  - Full width grey rectangles separated by spacing

**Profile Skeleton**:
- Cover rectangle at top
- Large circle (logo) in center
- Horizontal lines below (name, details)
- Multiple section blocks

Use light grey (#E5E7EB) for base, darker grey (#D1D5DB) for shimmer highlight. Smooth animation (1.5s loop).

---

## 45. EMPTY STATE SCREENS

**Prompt:**
Design empty state screens for various sections.

**No Orders Yet**:
- Shopping bag icon (64px, grey, with dotted outline)
- "No orders yet" heading (18px, bold, grey)
- "Orders will appear here when customers place them" text (14px, light grey)
- "Share your profile" button (blue, outlined) or illustration of sharing

**No Products**:
- Box icon (64px, grey, open/empty)
- "Your catalog is empty"
- "Add your first product to get started"
- "Add Product" button (blue, solid, with + icon)

**No Messages**:
- Chat bubble icon (64px, grey)
- "No messages yet"
- "Customer messages will appear here"
- No action button, just informational

**No Reviews**:
- Star outline icon (64px, grey)
- "No reviews yet"
- "Share your profile with customers to get reviews"
- "Share Profile" button (blue)

**No Team Members**:
- People icon (64px, grey)
- "Build your team"
- "Add team members to help manage your business"
- "Invite Member" button (blue)

All empty states: centered content, friendly icons, constructive messaging, relevant call-to-action. Light grey background or white.

---

## 46. ONBOARDING TUTORIAL OVERLAYS

**Prompt:**
Design tutorial overlay screens (coach marks).

**Overlay Background**: Semi-transparent dark overlay (black, 60% opacity) covering entire screen.

**Spotlight**: Circular or rounded-rectangle cutout (clear area) highlighting the specific UI element being explained. Subtle glow/border around cutout.

**Tutorial Bubble**: White rounded card (16px radius, shadow) positioned near the spotlighted element:
- Title "Add Your First Product" (16px, bold, black)
- Description text (14px, grey) "Tap here to add products to your catalog"
- Arrow/pointer from bubble to highlighted element
- Bottom: Step indicator "1 of 5" (12px, grey, left) and "Next" button (blue, right) or "Skip" link

**Tutorial Sequence**:
1. Spotlight Dashboard - "Welcome to your dashboard"
2. Spotlight + button - "Add products here"
3. Spotlight Messages tab - "Chat with customers"
4. Spotlight Profile tab - "Manage your profile"
5. Spotlight Settings - "Customize your experience"

**Navigation**: "Next" button (blue), "Skip" link (grey), progress dots at bottom showing current step.

**Completion Screen**: When tutorial completes - green checkmark, "You're all set!" message, "Get Started" button.

---

## 47. MULTI-SELECT & BULK ACTIONS UI

**Prompt:**
Design multi-select mode and bulk actions interface.

**Normal List View → Select Mode Transition**:
- Normal: Three-dot menu icon on each item
- Select mode: Checkbox appears on left of each item (circular, blue when checked, grey outline when unchecked)

**Top Bar Changes in Select Mode**:
- Back arrow changes to X (cancel selection)
- Title shows "2 selected" (dynamic count)
- Right side: "Select All" link (blue)

**Selected Items**:
- Item card has blue border or light blue background tint
- Checkbox shows blue checkmark

**Bottom Action Bar** (slides up when items selected):
- White bar with shadow, fixed at bottom
- Icons/buttons for bulk actions:
  - Delete (trash icon, red)
  - Archive (archive icon, grey)
  - Move to Category (folder icon, grey)
  - Export (download icon, blue)
  - Share (share icon, blue)

**Confirmation Dialog** (for destructive actions like delete):
- Modal overlay
- White rounded card (center screen)
- Warning icon (orange/red)
- "Delete 3 items?" heading (18px, bold)
- "This action cannot be undone" warning text (14px, grey)
- Two buttons: "Cancel" (grey, outlined), "Delete" (red, solid)

---

## 48. FILTERS & SORT MODAL

**Prompt:**
Design advanced filters modal. Bottom sheet slides up (white, rounded top 20px).

**Header**: "Filters" (18px, bold, left), "Reset" link (blue, right), handle bar at top.

**Filter Sections** (vertical scroll):

1. **Status** (radio buttons or chips):
   - All
   - Active (green dot)
   - Inactive (grey dot)
   - Out of Stock (red dot)

2. **Category** (multi-select checkboxes):
   - Checkbox + category name for each
   - Show count next to each category "(12)"

3. **Price Range** (dual-thumb slider):
   - Min input field | Slider | Max input field
   - Visual slider with two thumbs showing selected range in blue

4. **Date Range** (date pickers):
   - From Date | To Date
   - Calendar icon to open date picker

5. **Rating** (star selector):
   - Tap to select minimum rating: 1-5 stars (gold when selected)

6. **Other Filters**:
   - "On Sale" toggle
   - "In Stock" toggle
   - "Featured" toggle

**Bottom Bar**: "Clear All" (text button, grey), "Apply Filters" (solid button, blue) showing count "(45 results)".

**Sort Options** (separate modal or same modal, tab switch):
- Radio buttons: Newest First, Oldest First, Price: Low to High, Price: High to Low, Most Popular, Highest Rated

---

## 49. EXPORT/REPORT GENERATION SCREEN

**Prompt:**
Design export and report generation screen. Top app bar: back arrow, "Export Data" title.

**Report Type Selection** (large cards, single select):
- Sales Report (chart icon, blue)
- Inventory Report (box icon, orange)
- Customer Report (people icon, green)
- Financial Report (rupee icon, purple)

**Date Range**:
- Preset chips: Today, This Week, This Month, This Year, Custom (opens date picker)
- If custom: From Date | To Date fields

**Report Format** (radio buttons):
- PDF (document icon)
- Excel (spreadsheet icon)
- CSV (table icon)

**Include Options** (checkboxes):
- Include summary statistics
- Include charts and graphs
- Include detailed breakdown
- Include customer information

**Email Options**:
- "Email report to me" toggle
- Email address field (if toggle on)
- "Schedule recurring reports" toggle (if on, show frequency dropdown: Daily/Weekly/Monthly)

**Preview Section**: Grey card showing sample of report layout.

Bottom bar: "Cancel" and "Generate Report" (blue) buttons.

**Download Progress Modal** (after generating):
- Circular progress indicator with percentage "45%"
- "Generating report..." text
- Cancel button

**Download Complete**:
- Green checkmark
- "Report generated successfully"
- File name and size "sales_report.pdf (2.5 MB)"
- "Open" button (blue), "Share" button (outlined)

---

## 50. BUSINESS INSIGHTS & TIPS SCREEN

**Prompt:**
Design business insights and recommendations screen. Top app bar: "Insights" title, info icon.

**Performance Score Card** (top, gradient blue to purple):
- Large circular progress indicator (0-100 score) "85/100"
- "Excellent Performance!" text
- "Your business is performing well" subtext
- Small trend icon showing up/down from last period

**Key Insights** (cards with icons):

1. **Peak Hours Card**:
   - Clock icon (orange)
   - "Peak Hours" heading
   - "Your busiest time is 12 PM - 2 PM" text
   - Bar chart showing hourly activity
   - Action: "Optimize staffing" link (blue)

2. **Top Products Card**:
   - Trophy icon (gold)
   - "Best Sellers" heading
   - List of top 3 products with mini bar charts
   - Action: "View full report"

3. **Customer Retention Card**:
   - Heart icon (red)
   - "Customer Loyalty" heading
   - "45% of customers return within 30 days"
   - Action: "Launch loyalty program" (blue button)

4. **Growth Opportunities**:
   - Lightbulb icon (yellow)
   - "Suggestions for You" heading
   - List items:
     - "Add more product photos" (with camera icon)
     - "Enable online ordering" (with cart icon)
     - "Complete your business profile" (with star icon)
   - Each has right arrow to action

**Personalized Tips** (collapsible section):
- "Did you know?" cards with helpful business tips
- Swipeable carousel format

Light grey background, white cards with colored accents.

---

## DESIGN SYSTEM SUMMARY

**Color Palette**:
- Primary: #1E3A5F (Deep Blue)
- Accent: #2563EB (Bright Blue)
- Secondary: #3B82F6 (Light Blue)
- Success: #10B981 (Green)
- Warning: #F59E0B (Orange)
- Error: #EF4444 (Red)
- Grey Scale: #111827 (Black), #6B7280 (Grey), #E5E7EB (Light Grey), #F9FAFB (Background)

**Typography**:
- Headers: 28-32px, Bold, Black color
- Subheaders: 18-22px, Semi-Bold
- Body: 14-16px, Regular
- Labels: 14px, Medium Weight, Grey
- Captions: 12-13px, Regular, Light Grey

**Spacing**:
- Screen padding: 20px
- Card padding: 16px
- Element gaps: 12-16px
- Sections: 24-32px apart

**Components**:
- Border radius: 12px (cards), 25px (pills), 8px (small elements)
- Shadows: Subtle (2px offset, 0.05 opacity)
- Borders: 1px (default), 2px (selected state)
- Icons: 20-24px (inline), 32-40px (featured), 64px (empty states)

**Buttons**:
- Primary: Blue (#2563EB), white text, 12px radius, 16px vertical padding
- Secondary: Outlined, blue border, blue text
- Text: No background, blue text
- Disabled: Grey (#E5E7EB) background, grey text

**Input Fields**:
- Height: 48px
- Radius: 12px
- Border: 1px grey (default), 2px blue (focus)
- Padding: 16px horizontal
- Icons: 20px, grey, left-aligned with 12px right margin

---

---

## 51. SERVICES MANAGEMENT SCREEN

**Prompt:**
Design services management screen for service-based businesses (salons, clinics, gyms). Top app bar: "Services" title, search icon, filter icon, add (+) icon (blue).

**Service Categories Tabs**: Horizontal scrollable tabs: All Services, Hair, Skin Care, Massage, Nails (or category-appropriate).

**Services List**: Vertical scrolling cards (white, rounded 12px, 16px padding, 12px gaps):
Each service card shows:
- Left: Service icon or image (60px circle, colored background)
- Middle section (column):
  - Service name "Haircut & Styling" (16px, bold, black)
  - Description "Professional haircut with styling" (13px, grey, 2 lines max)
  - Duration icon + "45 mins" (13px, grey)
  - Staff icon + "3 staff available" (13px, grey)
- Right section:
  - Price "₹800" (18px, bold, blue)
  - Availability toggle (green when available)
  - Edit icon (small, grey)

**Service Package Section** (collapsible):
- "Service Packages" header with badge showing count "(5)"
- Package cards: "Bridal Package" with list of included services, total value, discounted price

**Popular badge**: Some services show orange "Popular" badge in top-right corner.

**Filter by**: Staff member, Duration, Price range (icons at top).

Light grey background. Floating action button (+) for adding new service.

---

## 52. SERVICE ADD/EDIT FORM

**Prompt:**
Design service creation form. Top app bar: back arrow, "Add Service" title, save icon (blue).

Scrollable white form:

1. **Service Photo**: Rounded container (150×150px, centered) with camera icon overlay. Show uploaded image or placeholder with scissors/service icon.

2. **Basic Details**:
   - Service Name* (input)
   - Category (dropdown: Hair, Skin, Nails, etc.)
   - Sub-category (dropdown: Cut, Color, Treatment, etc.)

3. **Description**: Multiline text area (4 rows) with character counter "0/300"

4. **Duration & Pricing**:
   - Duration (time picker or dropdown: 15min, 30min, 45min, 1hr, 1.5hr, 2hr)
   - Price* (rupee icon prefix, number input)
   - Member Price (optional, shows discount percentage automatically)

5. **Staff Assignment** (multi-select):
   - Checkboxes with staff profile photos (40px circles)
   - Staff name next to each photo
   - "All staff can perform this service" checkbox at top

6. **Availability Settings**:
   - "Available for booking" toggle (blue when on)
   - Advance booking window: "Can be booked up to [30] days in advance"
   - Buffer time: "Add [10] min buffer between appointments"

7. **Add-ons** (optional, collapsible):
   - List add-on services that can be added (checkboxes)
   - Each shows name and additional price

8. **Requirements/Instructions**:
   - Text area for "Client should arrive 10 minutes early"

9. **Tags**: Multi-select chips - Popular, New, Signature, Premium

Bottom bar: "Cancel" and "Save Service" buttons.

---

## 53. STAFF/TEAM MANAGEMENT SCREEN

**Prompt:**
Design team management screen. Top app bar: "Team" title (or "Staff"), search icon, add (+) icon (blue).

**Active/Inactive tabs**: All, Active (green badge "12"), Inactive (grey "2").

**Team Members Grid**: 2-column grid or list view toggle:

Each team card (white, rounded 12px, shadow):
- Top: Profile photo (80px circle, centered) or grey placeholder with initials
- Name "Sarah Johnson" (16px, bold, black, centered)
- Role badge "Senior Stylist" (blue pill, small, centered)
- Specialties row: Small chips showing "Hair", "Nails" (grey, small)
- Stats row: "156 bookings" | "4.8★ rating"
- Status indicator: "Available" (green dot) or "Busy" (orange dot) or "Off duty" (grey dot)
- Bottom action row: "View Schedule" link, "Edit" icon, three-dot menu

**Quick Stats Header**: Card showing "12 Team Members", "8 On Duty", "Next shift: 2:00 PM"

**Floating action button**: "+" to add new team member with two options: "Invite Staff" and "Add Manually"

Light grey background.

---

## 54. STAFF/TEAM MEMBER ADD/EDIT FORM

**Prompt:**
Design staff member creation form. Top app bar: back arrow, "Add Team Member" title, save icon.

White background form:

1. **Profile Photo**: Large circular upload area (100px) with camera icon

2. **Personal Information**:
   - Full Name*
   - Role/Title* (dropdown or input: Manager, Stylist, Therapist, Trainer, etc.)
   - Phone Number* (with country code)
   - Email Address
   - Date of Birth (date picker)

3. **Employment Details**:
   - Employee ID (auto-generated or custom)
   - Join Date* (date picker)
   - Employment Type (radio: Full-time, Part-time, Contractor)

4. **Skills & Specialties** (multi-select chips):
   - Checkboxes for services they can perform
   - Shows service names with icons

5. **Working Hours**:
   - Default schedule grid showing days of week
   - Each day: toggle (Works/Off) + time pickers (Start/End)
   - "Same hours every day" checkbox for quick setup

6. **Permissions & Access** (if user management):
   - Role dropdown: Admin, Manager, Staff, View Only
   - Toggles for: Can manage bookings, Can manage inventory, Can view reports, Can manage team

7. **Commission/Salary** (optional, collapsible, with lock icon):
   - Commission type: Radio buttons (Percentage, Fixed per service, Salary)
   - Rate input field
   - "This information is private" note

8. **Bio/About**: Text area for staff bio shown to customers

9. **Social Links**: Instagram, Facebook (optional)

Bottom bar: "Cancel" and "Save Team Member" buttons.

---

## 55. STAFF SCHEDULE/ROSTER SCREEN

**Prompt:**
Design team schedule calendar view. Top app bar: "Staff Schedule" title, calendar view toggle (Day/Week/Month), filter icon.

**Week View** (default):
- Top: Date navigation arrows, current week range "Jan 15-21, 2024"
- Left column: Time slots (8 AM - 8 PM, hourly rows)
- Top row: Days of week with staff names as column headers
  - Each column represents one staff member with profile photo (30px circle)

**Schedule Grid**: Time-slot based layout
- Each staff member has a vertical column
- Colored blocks represent appointments/bookings:
  - Blue: Booked appointments (shows customer name, service, time)
  - Green: Available slots
  - Grey: Break time
  - Red: Time off
- Drag-and-drop enabled (show cursor change on hover)

**Staff Row Headers** (left side if vertical layout):
- Profile photo + name
- Shift time "9 AM - 6 PM"
- Availability count "5 slots available"

**Legend** (bottom sticky bar):
- Color codes: Booked (blue), Available (green), Break (grey), Off (red)

**Quick Actions** (floating):
- "Add Block Time" button
- "Mark Day Off" button
- "Copy Schedule" button (to duplicate to next week)

White background, grid lines in light grey, colored blocks for different states.

---

## 56. COURSES MANAGEMENT SCREEN (EDUCATION)

**Prompt:**
Design courses management for education businesses. Top app bar: "Courses" title, search icon, filter icon, add (+) icon (blue).

**Filter tabs**: All Courses, Active, Upcoming, Completed, Draft.

**Course Cards**: Vertical scrolling list (white, rounded 12px, shadow):
Each card:
- Left: Course thumbnail image (100×100px, rounded 8px) or subject icon placeholder
- Middle section:
  - Course name "Advanced Mathematics" (18px, bold, black)
  - Instructor "by Prof. John Smith" with profile photo (13px, grey)
  - Duration badge "6 months" + Level badge "Intermediate" (grey pills)
  - Stats row: "45 students enrolled" | "₹15,000 fees"
  - Progress bar (if ongoing) showing completion percentage
- Right section:
  - Status badge: "Active" (green), "Starting Soon" (blue), "Completed" (grey)
  - Enrollment status "40/50 seats filled"
  - Edit and delete icons

**Course Type Icons**: Show if Online (wifi icon), Offline (location icon), or Hybrid (both icons).

**Batch Information**: If multiple batches, show expandable section with batch timings.

Light grey background. Floating action button (+) to create new course.

---

## 57. COURSE ADD/EDIT FORM (EDUCATION)

**Prompt:**
Design course creation form. Top app bar: back arrow, "Add Course" title, save icon.

White background form:

1. **Course Image**: Upload area (16:9 ratio, rounded 12px)

2. **Course Details**:
   - Course Name*
   - Category (dropdown: Academic, Professional, Hobby, etc.)
   - Subject (dropdown or input)
   - Course Code (e.g., "MATH-101")

3. **Description**: Rich text area with formatting options (bold, italic, bullets)

4. **Course Level**: Radio buttons - Beginner, Intermediate, Advanced

5. **Duration & Schedule**:
   - Total Duration (number + unit dropdown: Weeks/Months/Years)
   - Start Date* | End Date
   - Class Days (multi-select checkboxes: Mon, Tue, Wed...)
   - Class Timings (time pickers: From - To)
   - Total Classes (number input)

6. **Delivery Mode**:
   - Radio buttons: In-Person, Online, Hybrid
   - If online: Platform field (Zoom, Google Meet, etc.)
   - If in-person: Classroom/Location dropdown

7. **Instructor Assignment**:
   - Primary Instructor (dropdown with staff profiles)
   - Co-instructors (optional, multi-select)

8. **Enrollment**:
   - Maximum Students* (number)
   - Minimum Students to start (number)
   - Enrollment deadline (date picker)

9. **Pricing**:
   - Course Fees* (rupee icon)
   - Registration Fee (optional)
   - Early bird discount (percentage, with expiry date)
   - Installment options toggle

10. **Prerequisites** (optional):
    - Text area listing required prior knowledge

11. **Syllabus/Curriculum**:
    - Expandable sections for adding modules/topics
    - Each module: Title, Description, Duration

12. **Materials Included**: Checkboxes - Books, Notes, Certificates, Kit, etc.

Bottom bar: "Save as Draft" (outlined) and "Publish Course" (blue solid).

---

## 58. ENROLLMENTS SCREEN (EDUCATION)

**Prompt:**
Design student enrollments management screen. Top app bar: "Enrollments" title, filter icon, export icon.

**Filter tabs**: All, Pending, Active, Completed, Dropped.

**Search & Filters**: Search bar with "Search by student name, course, phone..."

**Enrollment List**: Cards showing enrollment details (white, rounded 12px):
Each card:
- Left: Student profile photo (50px circle)
- Middle section:
  - Student name (16px, bold)
  - Course enrolled "Advanced Mathematics - Batch A" (14px, grey)
  - Enrollment date "Enrolled: Jan 15, 2024" (13px, light grey)
  - Payment status: "Paid ₹15,000" (green) or "Pending ₹5,000" (orange) or "Installment 2/3" (blue)
  - Attendance: Progress bar "85% attendance (34/40 classes)"
- Right section:
  - Status badge: "Active" (green pill), "Pending" (orange), "Completed" (blue)
  - Action buttons: "View Details", "Contact", three-dot menu

**Quick filters chips** (horizontal scroll): This Month, Fee Pending, Poor Attendance, Completing Soon.

**Bulk Actions**: Multi-select mode for sending announcements, marking attendance, generating certificates.

Light grey background.

---

## 59. VEHICLES MANAGEMENT SCREEN (AUTOMOTIVE)

**Prompt:**
Design vehicles inventory screen for automotive businesses. Top app bar: "Vehicles" title, grid/list toggle, filter icon, add (+) icon.

**Filter tabs**: All, For Sale, Sold, Under Service, Reserved.

**Vehicle Cards** (grid view, 2 columns):
Each card (white, rounded 12px, no padding):
- Top: Vehicle photo (full width, 180px height, rounded top) or car placeholder
- Bottom section (12px padding):
  - Vehicle name "Honda City 2023" (16px, bold)
  - Variant "VX CVT Petrol" (13px, grey)
  - Specs row: Fuel icon "Petrol", Transmission icon "Automatic", Year "2023" (small icons + text)
  - Mileage "15,000 km" (13px, grey)
  - Price "₹12,50,000" (18px, bold, blue)
  - Status badge: "Available" (green), "Sold" (grey), "Reserved" (orange)
  - Bottom row: "Edit" icon, "Details" link (blue), three-dot menu

**List View**: Shows same info in horizontal layout with larger photo on left.

**Filter options**: Make, Model, Year, Price Range, Fuel Type, Transmission.

Light grey background. Floating action button (+) to add vehicle.

---

## 60. VEHICLE ADD/EDIT FORM (AUTOMOTIVE)

**Prompt:**
Design vehicle listing form. Top app bar: back arrow, "Add Vehicle" title, save icon.

White form with sections:

1. **Vehicle Photos**: Horizontal scrollable gallery (upload up to 10 photos)
   - First slot: "+" add photo
   - Subsequent: 120×120px squares with delete X icon
   - "Set as primary" option on first photo

2. **Basic Information**:
   - Make* (dropdown: Honda, Toyota, BMW, etc.)
   - Model* (dropdown, filtered by make)
   - Year* (year picker)
   - Variant (input: VX, ZX, etc.)

3. **Specifications**:
   - Fuel Type* (dropdown: Petrol, Diesel, Electric, Hybrid)
   - Transmission* (dropdown: Manual, Automatic, CVT)
   - Engine Capacity (input + "cc" suffix)
   - Mileage (input + "kmpl" suffix)
   - Seating Capacity (number input)
   - Color* (dropdown with color swatches)

4. **Condition**:
   - Radio buttons: New, Used, Certified Pre-Owned
   - If used: Odometer Reading (km), Number of Owners

5. **Pricing**:
   - Selling Price* (rupee icon)
   - MRP (optional, shows discount calculation)
   - Negotiable (toggle)

6. **Vehicle Status**:
   - Radio buttons: For Sale, Sold, Under Service, Reserved

7. **Registration Details** (if used):
   - Registration Number
   - Registration Year
   - RTO Location

8. **Features** (multi-select chips):
   - ABS, Airbags, Power Steering, Power Windows, AC, Sunroof, Alloy Wheels, Bluetooth, Navigation, Parking Sensors, Backup Camera, etc.

9. **Description**: Text area for additional details

10. **Service History** (collapsible):
    - Last service date
    - Service records (upload documents)

11. **Insurance Details**:
    - Insurance valid until (date picker)
    - Insurance type (Comprehensive/Third Party)

Bottom bar: "Save as Draft" and "Publish Listing" buttons.

---

## 61. PROPERTIES MANAGEMENT SCREEN (REAL ESTATE)

**Prompt:**
Design properties listing screen for real estate. Top app bar: "Properties" title, map view toggle, filter icon, add (+) icon.

**Filter tabs**: All, For Sale, For Rent, Sold, Rented.

**Property Cards**: List or grid view
Each card (white, rounded 12px):
- Top: Property image (full width, 200px height) with image count badge "1/8" (top-right corner)
- Heart icon (top-right, for favorites)
- Featured badge (if applicable, orange ribbon top-left)
- Bottom section (16px padding):
  - Property type badge "Apartment" or "Villa" (blue pill)
  - Property name/title "Luxury 3BHK Apartment" (18px, bold)
  - Location with pin icon "Downtown, New York" (13px, grey)
  - Size "1,850 sq.ft" | Bedrooms "3 BHK" | Bathrooms "2" (icons + text)
  - Price "₹75 Lakhs" or "₹25,000/month" (22px, bold, blue)
  - Status: "Ready to Move" (green) or "Under Construction" (orange)
  - Bottom row: "Edit", "View Details" link, "Share" icon, three-dot menu

**Map View**: Shows properties as pins on Google Maps, tap pin to see property card preview.

**Quick Stats Header**: "45 Properties", "28 For Sale", "12 For Rent", "5 Sold this month"

Light grey background.

---

## 62. PROPERTY ADD/EDIT FORM (REAL ESTATE)

**Prompt:**
Design property listing form. Top app bar: back arrow, "Add Property" title, save icon.

Multi-section scrollable form:

1. **Property Photos & Video**:
   - Photo gallery upload (up to 20 photos)
   - Video tour upload (optional)
   - Virtual tour link (optional)

2. **Property Type**:
   - Radio buttons: Apartment, Villa, Plot, Office, Shop, Warehouse, PG/Hostel

3. **Basic Details**:
   - Property Name/Title*
   - Description* (rich text, 1000 chars)
   - Built-up Area* (sq.ft input)
   - Carpet Area (sq.ft input)
   - Plot Area (if applicable)

4. **Configuration**:
   - Bedrooms* (stepper: 1, 2, 3, 4, 4+)
   - Bathrooms* (stepper)
   - Balconies (stepper)
   - Floors (dropdown: Ground, 1st, 2nd... Penthouse)
   - Total Floors in Building

5. **Pricing**:
   - Listing Type: Radio - For Sale / For Rent / Both
   - Sale Price (if for sale, rupee icon)
   - Rent Amount (if for rent, rupee icon + "/month")
   - Maintenance Charges (optional, rupee icon + "/month")
   - Security Deposit (if for rent)
   - Negotiable (toggle)

6. **Location**:
   - Address* (multi-line)
   - Locality/Area*
   - City*, State*, PIN Code*
   - Map picker (same as business location step 4)

7. **Property Status**:
   - Radio: Ready to Move, Under Construction
   - If under construction: Possession date (date picker)
   - Age of Property (if ready: dropdown - Less than 1 year, 1-5 years, 5-10 years, 10+ years)

8. **Furnishing**:
   - Radio: Unfurnished, Semi-Furnished, Fully Furnished
   - If furnished: Checkboxes for items (Sofa, Bed, Wardrobe, AC, TV, Fridge, etc.)

9. **Amenities** (multi-select chips):
   - Parking, Lift, Power Backup, Security, Gym, Swimming Pool, Garden, Club House, Children's Play Area, etc.

10. **Facing Direction**: Dropdown - North, South, East, West, North-East, etc.

11. **Availability**:
    - Available From (date picker)
    - Preferred Tenants (if rent): Family, Bachelor, Company, Any

12. **Legal Details**:
    - Ownership Type (Freehold/Leasehold)
    - Approved by: RERA number input
    - Clear Title (toggle)

Bottom: "Save as Draft", "Preview", "Publish Listing" buttons.

---

## 63. MEMBERSHIPS SCREEN (FITNESS/WELLNESS)

**Prompt:**
Design membership plans screen. Top app bar: "Memberships" title, active members icon (shows count), add (+) icon.

**Membership Plans Cards**: Vertical scrolling
Each plan card (white, rounded 12px, 16px padding, colorful left border - different color per plan):
- Plan name "Gold Membership" (20px, bold)
- Popular badge (orange, if applicable)
- Duration badge "12 Months" (grey pill)
- Price "₹18,000" (24px, bold, blue) with "₹1,500/month" below (14px, grey)
- Discount badge "Save 20%" (green pill) if applicable
- Benefits list (checkmarks):
  - "Unlimited gym access"
  - "All group classes included"
  - "1 free PT session monthly"
  - "Guest pass (2/month)"
- Stats: "45 active members" (13px, grey)
- Bottom row: "Edit Plan" link (blue), "View Members" link, three-dot menu

**Plan Types**: Categorized by tabs - All, Gym, Classes, Personal Training, Combo.

**Quick Add**: Common duration templates (1 Month, 3 Months, 6 Months, 12 Months) as quick-create buttons.

Floating action button (+) to create custom plan.

Light grey background.

---

## 64. MEMBERSHIP PLAN ADD/EDIT FORM (FITNESS)

**Prompt:**
Design membership plan creation form. Top app bar: back arrow, "Create Membership Plan" title, save icon.

White form:

1. **Plan Name*** (input: Gold, Platinum, Basic, etc.)

2. **Plan Type**: Radio buttons - Gym Only, Classes Only, Personal Training, All Access

3. **Duration & Pricing**:
   - Duration* (radio): 1 Month, 3 Months, 6 Months, 12 Months, Lifetime
   - Total Price* (rupee icon)
   - Auto-calculate: "₹X per month" shown below
   - Compare with: Dropdown to show savings vs other plans

4. **Payment Options**:
   - One-time payment (toggle)
   - Installments allowed (toggle) - if on, show installment schedule input

5. **Access & Benefits** (checkboxes):
   - Unlimited gym access
   - Group classes access: All / Limited (number input)
   - Personal training sessions: Number per month
   - Guest passes: Number per month
   - Locker facility
   - Nutrition consultation
   - Steam/Sauna access
   - Towel service
   - Protein shake included

6. **Restrictions** (optional):
   - Peak hours restriction toggle (if on: time picker for off-peak hours)
   - Specific equipment restriction
   - Freeze allowed: Number of times (input)

7. **Renewal**:
   - Auto-renewal (toggle) - if on, show renewal discount percentage
   - Grace period after expiry: Number of days

8. **Registration Fee**: Amount (one-time, rupee icon)

9. **Limits**:
   - Maximum members for this plan (optional, for exclusive plans)

10. **Discount & Offers**:
    - Launch offer (toggle) - percentage discount with expiry date
    - Referral discount (percentage)

11. **Plan Description**: Text area explaining what's included

12. **Terms & Conditions**: Text area for plan-specific T&C

Bottom bar: "Save as Draft" and "Publish Plan" buttons.

---

## 65. MEMBER ENROLLMENT (FITNESS/WELLNESS)

**Prompt:**
Design member enrollment form. Top app bar: back arrow, "New Member Enrollment" title.

White form:

1. **Member Search**: "Existing customer?" search bar to search existing database

2. **Personal Information**:
   - Full Name*
   - Phone* (country code picker)
   - Email
   - Date of Birth* (for age-appropriate programs)
   - Gender (radio: Male, Female, Other)
   - Profile photo upload

3. **Address**: Street, City, State, PIN Code

4. **Emergency Contact**:
   - Name*
   - Relationship*
   - Phone*

5. **Health Information** (collapsible, with privacy lock icon):
   - Blood Group (dropdown)
   - Any medical conditions (text area)
   - Medications (text area)
   - Allergies (text area)
   - "I confirm this information is accurate" checkbox

6. **Membership Selection***:
   - Plan cards (same as membership screen) - single select
   - Selected plan shows blue border
   - Shows price, duration, benefits

7. **Start Date***: Date picker (default: today)

8. **Payment**:
   - Amount to pay: Auto-filled from plan price
   - Payment mode: Radio - Cash, Card, UPI, Net Banking, Cheque
   - If installment: Show schedule (1st payment now: ₹X, 2nd payment: Date, etc.)
   - Payment status: Paid / Pending

9. **Additional Add-ons** (optional):
   - Personal training package (checkbox + price)
   - Nutrition plan (checkbox + price)
   - Locker rental (checkbox + price)

10. **Documents Upload**:
    - ID Proof (upload)
    - Photo (upload)
    - Medical certificate (optional, upload)

11. **Referral**: "Referred by" (search existing members) - gives referrer discount

12. **Terms Agreement***:
    - Checkbox: "I accept the terms and conditions"
    - Link to view full T&C

Bottom bar: "Save as Draft" and "Complete Enrollment" (blue) buttons.

Success screen after enrollment: Green checkmark, "Welcome [Name]!" heading, Member ID card preview with QR code, "Print Card" button, "Send Welcome Email" button.

---

## 66. INQUIRIES MANAGEMENT SCREEN

**Prompt:**
Design customer inquiries management screen. Top app bar: "Inquiries" title, filter icon, refresh icon.

**Filter tabs**: All, New (with badge "8"), In Progress, Responded, Closed.

**Inquiry Cards**: Vertical scrolling list (white, rounded 12px, 16px padding):
Each inquiry card:
- Top row:
  - Priority indicator: Colored left border (Red=High, Orange=Medium, Green=Low)
  - Inquiry ID "#INQ-1234" (13px, grey)
  - Time "2 hours ago" (13px, grey, right-aligned)
- Customer info row:
  - Profile photo (40px circle) or initials
  - Customer name (16px, bold)
  - Contact: phone icon + number (13px, grey)
- Inquiry type badge: "Product Inquiry" or "Service Inquiry" or "Booking" (blue pill)
- Inquiry text preview: "I'm interested in..." (14px, grey, 2 lines, truncated)
- If attachments: Paperclip icon + "2 attachments" (13px, grey)
- Status badge (right): "New" (orange), "Responded" (blue), "Closed" (grey)
- Bottom action row: "Reply" button (outlined, blue), "Call" icon, "Mark as Closed" link, three-dot menu

**Quick Actions Bar** (sticky at top after tabs):
- Bulk select mode toggle
- Sort by: Dropdown (Newest, Oldest, Priority)
- Auto-assign toggle (assigns to staff automatically)

**Empty state**: If no inquiries - question mark icon, "No inquiries yet", "Inquiries from customers will appear here"

Light grey background. Floating action button (+) to create manual inquiry entry.

---

## 67. INQUIRY DETAIL SCREEN

**Prompt:**
Design inquiry detail view. Top app bar: back arrow, "Inquiry #INQ-1234" title, status badge (dynamic color), three-dot menu.

**Customer Card** (white, rounded 12px, 16px padding):
- Left: Profile photo (60px circle)
- Right section:
  - Name (18px, bold)
  - Phone with "Call" button (blue chip)
  - Email with "Email" button (blue chip)
  - "View Full Profile" link

**Inquiry Details Card**:
- Inquiry Type: "Service Inquiry" (blue pill)
- Priority: Stars or color indicator (High/Medium/Low)
- Category: "Haircut & Styling"
- Received on: "Jan 15, 2024, 2:30 PM"
- Source: "Website Form" or "Phone Call" or "Walk-in"

**Inquiry Message Card**:
- Full inquiry text (readable, good line spacing)
- If attachments: Image thumbnails or file icons (tap to view/download)

**Timeline/History Card**:
- Vertical timeline showing all interactions:
  - Inquiry received (grey circle, timestamp)
  - Viewed by Staff (blue circle, staff name, timestamp)
  - Response sent (green circle, timestamp)
  - Follow-up scheduled (orange circle, timestamp)
  - Closed (grey circle, timestamp)

**Response Section** (if responded):
- White card showing previous responses
- Staff member photo + name who responded
- Response text
- Timestamp

**Action Buttons** (bottom fixed bar):
- "Reply" (blue, solid) - opens reply modal
- "Schedule Follow-up" (outlined)
- "Convert to Booking" (outlined, green)
- "Mark as Closed" (text button, grey)

**Reply Modal** (bottom sheet):
- Text area for response
- Template responses chips: "Thanks for your interest", "Will call you soon", "Check our services"
- Attachments icon
- Send button (blue)

Light grey background.

---

## 68. BUSINESS POSTS/UPDATES SCREEN

**Prompt:**
Design business posts management screen. Top app bar: "Posts & Updates" title, filter icon, add (+) icon (blue).

**Post Types Tabs**: All, Offers, Announcements, Events, Tips, Achievements.

**Posts Feed**: Instagram-style card layout
Each post card (white, rounded 12px, no padding):
- Top: Post image/video (full width, 16:9 aspect ratio) or gradient background if text-only
- Middle section (16px padding):
  - Post type badge: "Offer" (orange), "Event" (blue), "Tip" (green)
  - Post title/headline (18px, bold) "Grand Opening Sale!"
  - Post description (14px, grey, 3 lines, "Read more" if longer)
  - Validity dates (if offer): Calendar icon + "Valid till Jan 31" (13px, grey)
- Engagement stats row:
  - Views: eye icon + "1.2K views"
  - Likes: heart icon + "234 likes"
  - Shares: share icon + "56 shares"
- Bottom row:
  - Published timestamp "2 days ago" (13px, grey)
  - Status: "Published" (green dot) or "Draft" (grey dot)
  - Edit icon, three-dot menu (Pin, Delete)

**Quick Filters**: Chips for "Published", "Scheduled", "Draft", "Archived"

**Create Post Button** (floating action button with speed dial):
- Tap to expand: Offer, Event, Announcement, Tip, Achievement options

Light grey background.

---

## 69. CREATE POST FORM

**Prompt:**
Design business post creation form. Top app bar: back arrow, "Create Post" title, preview icon, post icon (blue).

White form:

1. **Post Type*** (large icon cards, single select):
   - Offer (tag icon, orange)
   - Event (calendar icon, blue)
   - Announcement (megaphone icon, purple)
   - Tip (lightbulb icon, yellow)
   - Achievement (trophy icon, green)

2. **Media Upload**:
   - Image/Video upload area (16:9 ratio, rounded 12px)
   - "Tap to add photo or video" placeholder
   - "Use template" button (opens template library with designs)

3. **Post Content**:
   - Title* (input, 60 chars max)
   - Description* (text area, 300 chars max, with counter)
   - Hashtags (input with # prefix, chips created)

4. **Offer Details** (if post type = Offer):
   - Discount percentage (number input + %)
   - Offer code (input, auto-generate button)
   - Valid from - Valid till (date pickers)
   - Terms & Conditions (text area)

5. **Event Details** (if post type = Event):
   - Event date & time (date time pickers)
   - Location (use business location or custom)
   - Registration required (toggle)
   - Max attendees (number input)
   - Registration link (input)

6. **Call-to-Action**:
   - CTA button type (dropdown): Book Now, Visit Us, Call Now, Learn More, Shop Now, Register
   - CTA link (input, if applicable)

7. **Visibility**:
   - Target audience (radio): All Customers, Members Only, New Visitors
   - Pin to top (toggle)

8. **Schedule**:
   - Publish (radio): Now, Schedule for later (date time picker if selected)
   - Auto-unpublish after (optional, date picker for offers/events)

9. **Preview Card**: Shows how post will look to customers (can be tapped for full preview)

Bottom bar: "Save as Draft" (outlined), "Preview" (outlined), "Publish Post" (blue solid).

---

## 70. BUSINESS HOURS DETAILED SCREEN

**Prompt:**
Design business hours management screen. Top app bar: back arrow, "Business Hours" title, save icon.

**Current Status Card** (top, prominent):
- Large icon (green if open, red if closed)
- Status text "Open Now" or "Closed" (22px, bold)
- Next change info "Closes at 9:00 PM" (14px, grey)
- "Temporarily close today" button (outlined, orange)

**Regular Hours Section**:
Each day card (white, rounded 12px, 16px padding, 8px gaps):
- Day name "Monday" (16px, bold, left)
- Toggle switch (right) - ON = working day, OFF = closed
- If ON: Time pickers showing "9:00 AM - 6:00 PM"
  - Two time picker buttons (tap to change)
  - If split shift: "+ Add break" or "+ Add evening shift" button
- If OFF: "Closed" text (grey)

**Split Hours Example** (if added):
- Morning: 9:00 AM - 1:00 PM
- Evening: 5:00 PM - 9:00 PM
- Shows as two rows with "Remove" icon

**Quick Actions**:
- "Copy Monday hours to all weekdays" button (outlined, blue)
- "Copy Monday hours to all days" button
- "Set 24/7" button (toggles all to always open)

**Special Hours Section**:
- "Add Special Hours" button (outlined)
- List of special dates (holidays, extended hours):
  - Date "Dec 25, 2024" | Special timing "Closed - Christmas" | Remove icon
  - Date "Jan 1, 2025" | "10:00 AM - 4:00 PM - New Year" | Remove icon

**Temporary Closure**:
- "Temporarily close business" section (collapsible, red icon)
- From date picker | To date picker
- Reason (dropdown: Holiday, Renovation, Emergency, Other)
- Customer message (text input) "We'll be back on..."
- "Apply" button (red)

**Display Settings**:
- Show "Open Now/Closed" badge on profile (toggle)
- Show next opening time if closed (toggle)

Bottom bar: "Cancel" and "Save Hours" buttons.

Light grey background.

---

## 71. HOLIDAY CALENDAR SCREEN

**Prompt:**
Design holiday calendar management. Top app bar: back arrow, "Holiday Calendar" title, add (+) icon.

**Year Selector**: Dropdown at top showing "2024" with arrows to change year.

**Calendar View**: Monthly calendar grid showing:
- Current month name "January 2024" (18px, bold, centered)
- Previous/next month arrows
- Calendar grid (7 columns for days)
- Holidays marked with colored dots or background tint (red for holidays)
- Business open days: white background
- Holidays: light red background
- Special hours: orange background

**Holiday List** (below or side-by-side with calendar):
Scrollable list of holiday cards (white, rounded 12px):
- Holiday date "Jan 26, 2024" (14px, bold, left)
- Holiday name "Republic Day" (16px, black)
- Status: "Business Closed" (red pill) or "Special Hours: 10 AM - 2 PM" (orange pill)
- Optional note "National Holiday" (13px, grey)
- Edit icon, delete icon

**Presets Section**:
- "Import holidays" button opens modal with options:
  - National Holidays (country selector)
  - Religious Holidays (religion selector)
  - Regional Holidays (state/region selector)
- Checkboxes to select which holidays to import
- "Import Selected" button

**Add Holiday Modal** (bottom sheet):
- Holiday name* (input or dropdown with common holidays)
- Date* (date picker)
- Type (dropdown: Public Holiday, Company Holiday, Custom)
- Business status (radio): Closed, Special Hours, Open as usual
- If special hours: Time pickers
- Repeat yearly (checkbox)
- Note (text area, optional)
- Save button

Light grey background.

---

## 72. DELIVERY AREAS / SERVICE AREAS SCREEN

**Prompt:**
Design service area management screen. Top app bar: back arrow, "Service Areas" title, add area (+) icon.

**Service Type** (if applicable):
- Tabs: Delivery, On-site Service, Pickup Only

**Map View** (prominent, top half of screen):
- Google Maps showing business location (pin)
- Service area overlay (colored polygon or circles)
- Multiple areas shown in different colors
- Zoom controls

**Areas List** (bottom half):
Vertical scrollable cards (white, rounded 12px):
Each area card:
- Area name "Downtown" (18px, bold)
- Coverage badge "5 km radius" or "15 locations" (grey pill)
- Delivery fee "₹50" or "Free" (16px, blue/green)
- Estimated time "30-45 mins" (13px, grey)
- Number of deliveries "234 deliveries" (13px, light grey)
- Toggle switch (Enable/Disable area) - blue when on
- Edit and delete icons

**Add by**:
- Radius (toggle) - if on: radius slider (1km - 50km)
- PIN codes (toggle) - if on: text input for comma-separated PIN codes
- Landmarks (toggle) - if on: search and select nearby landmarks
- Custom polygon (toggle) - if on: "Draw on map" button

**Delivery Settings** (collapsible section):
- Minimum order value for delivery (rupee input)
- Free delivery above (rupee input)
- Maximum delivery distance (km input)
- Delivery slots (time ranges)

**Add Area Modal**:
- Area name* (input)
- Selection method (radio): Radius, PIN Codes, Custom Polygon
- Based on selection: appropriate inputs
- Delivery fee* (rupee input, "Free" checkbox)
- Estimated delivery time (number input + unit dropdown)
- Save button

Light grey background.

---

## 73. TAX & GST SETTINGS SCREEN

**Prompt:**
Design tax settings screen. Top app bar: back arrow, "Tax & GST Settings" title, save icon.

**GST Registration Card**:
- Status badge: "GST Registered" (green) or "Not Registered" (orange)
- If registered:
  - GSTIN number (input, with edit icon)
  - Business legal name (input)
  - Registration date (date picker)
  - State (dropdown)
  - "Verified" checkmark (green) or "Verification pending" (orange)

**Tax Configuration**:

1. **GST Rates** (if registered):
   - Default GST rate (radio):
     - 0% (Exempt)
     - 5%
     - 12%
     - 18%
     - 28%
   - Custom rate (input, %)

2. **Tax Type** (radio):
   - CGST + SGST (for intrastate)
   - IGST (for interstate)
   - Auto-detect based on customer location (recommended)

3. **Product/Service-wise Tax**:
   - Toggle: "Apply different tax rates for different items"
   - If on: Link to "Manage item tax categories" screen

4. **Tax Display Settings**:
   - Radio:
     - Show prices with tax (inclusive)
     - Show prices without tax (exclusive, add tax at checkout)
   - Show tax breakup on invoice (toggle)

5. **Invoicing**:
   - Invoice number prefix (input, e.g., "INV-")
   - Starting number (input, for next invoice)
   - Invoice template (dropdown with preview)

**MSME/Udyam Registration** (optional section):
- Udyam registration number (input)
- Category (radio): Micro, Small, Medium

**TDS Settings** (if applicable):
- TDS deduction applicable (toggle)
- TDS percentage (input)

**HSN/SAC Codes** (collapsible):
- Link to "Manage HSN codes" for products
- Link to "Manage SAC codes" for services

**Compliance**:
- GST filing frequency (dropdown): Monthly, Quarterly
- Next filing due date (date display, red if overdue)
- "File GST Return" button (links to external portal or integrated tool)

Bottom bar: "Cancel" and "Save Settings" buttons.

Light grey background, with informational tooltips (i icons) next to complex fields.

---

## 74. AUTO-REPLY MESSAGES SCREEN

**Prompt:**
Design auto-reply settings screen. Top app bar: back arrow, "Auto-Reply Messages" title, master toggle (enable/disable all).

**Master Toggle Card** (top):
- Large toggle switch
- "Auto-Reply Enabled" text (18px, bold)
- Status: "Customers will receive automatic responses" (14px, grey)

**Trigger-based Replies**:
Each trigger card (white, rounded 12px, 16px padding, 12px gaps):

1. **Welcome Message**:
   - Icon: hand wave
   - "First Message from New Customer" (16px, bold)
   - Toggle switch (right, blue when on)
   - Text area showing current message: "Hi! Thanks for reaching out. We'll respond shortly."
   - Edit button (blue, outlined)
   - Preview button (shows how it looks to customer)

2. **Business Hours Reply**:
   - Icon: clock
   - "Outside Business Hours" (16px, bold)
   - Toggle switch
   - Message: "Thanks for your message! We're currently closed. We'll reply when we open at 9:00 AM."
   - Variables available: {business_name}, {opening_time}, {customer_name}

3. **Busy/Away Reply**:
   - Icon: busy indicator
   - "When Marked as Busy/Away" (16px, bold)
   - Toggle switch
   - Message + edit button

4. **Specific Keywords**:
   - Icon: text message
   - "Keyword Triggers" (16px, bold)
   - List of keyword-response pairs:
     - Keyword "price" → Reply "Our pricing starts at ₹500. Visit our website for details." (edit/delete icons)
     - Keyword "hours" → Reply auto-filled from business hours
   - "+ Add keyword trigger" button

5. **Booking Confirmation**:
   - Icon: checkmark
   - "After Successful Booking" (16px, bold)
   - Toggle switch
   - Message with booking details variables: {booking_id}, {date}, {time}, {service}

6. **Order Status Updates**:
   - Icon: package
   - "Order Status Changes" (16px, bold)
   - Toggles for each status: Order Placed, Preparing, Ready, Out for Delivery, Delivered
   - Each has customizable message

**Response Time Settings**:
- Delay before sending (seconds input): "Send reply after [5] seconds"
- Maximum messages per customer (to avoid spam): "[3] auto-replies per hour"

**Quick Reply Templates** (collapsible):
- Pre-written common replies that staff can use with one tap:
  - "Thanks for your interest"
  - "We'll call you shortly"
  - "Please check our menu"
  - etc.
- "+ Add template" button

**Edit Message Modal**:
- Text area with character counter (160 for SMS mode, 1000 for app)
- Variables dropdown to insert: Customer Name, Business Name, Date, Time, etc.
- Emoji picker icon
- Preview section
- "Save" button

Bottom: "Reset to defaults" link (grey).

Light grey background.

---

## 75. BOOKING SETTINGS DETAILED SCREEN

**Prompt:**
Design booking configuration screen. Top app bar: back arrow, "Booking Settings" title, save icon.

**Online Booking** (master toggle card):
- Large toggle switch
- "Accept Online Bookings" (18px, bold)
- Status text when on: "Customers can book appointments via your profile"

**Booking Rules Section**:

1. **Advance Booking**:
   - Minimum advance time: Number input + unit (Hours/Days) "Book at least [2] hours in advance"
   - Maximum advance time: "Book up to [30] days in advance"

2. **Same-Day Booking**:
   - Allow same-day booking (toggle)
   - Cut-off time: "Stop same-day booking after [2:00 PM]"

3. **Booking Window**:
   - Slot duration: Dropdown (15 min, 30 min, 45 min, 1 hour)
   - Buffer time between bookings: "[10] minutes buffer"
   - Maximum bookings per slot: "[3] customers per slot" (for classes)

4. **Cancellation Policy**:
   - Allow customer cancellation (toggle)
   - Free cancellation window: "[24] hours before appointment"
   - Cancellation fee: Dropdown (No fee, 25%, 50%, 100% of booking amount)

5. **Reschedule Policy**:
   - Allow customer reschedule (toggle)
   - Free reschedule window: "[12] hours before appointment"
   - Maximum reschedules allowed: "[2] times per booking"

6. **No-Show Policy**:
   - Mark as no-show if: "[15] minutes late"
   - No-show penalty: Dropdown (Warning, Block from booking, Charge fee)

**Payment Settings**:
- Require advance payment (toggle)
- If on: Payment amount (radio)
  - Full payment
  - Partial payment: [50]% of total
  - Fixed token amount: ₹[500]
- Payment methods accepted (checkboxes): Online, Cash, Card at venue

**Confirmation Settings**:
- Auto-confirm bookings (toggle) OR Require manual approval
- Send confirmation: Checkboxes for Email, SMS, WhatsApp
- Send reminder: Toggle + timing "[1] day before and [2] hours before"

**Waitlist Settings**:
- Enable waitlist when slots full (toggle)
- Auto-notify waitlist when slot opens (toggle)
- Waitlist expiry time: "Waitlist offer expires in [30] minutes"

**Availability Display**:
- Show remaining slots to customers (toggle): "5 slots available"
- Show "Almost full" when: "[3] slots remaining"

**Staff Assignment**:
- Booking assignment (radio):
  - Customer chooses staff
  - Auto-assign to available staff
  - Admin assigns manually

**Special Dates**:
- Link to "Blocked dates" (holidays, maintenance days)
- Link to "Special availability" (extended hours for events)

Bottom bar: "Reset to defaults" and "Save Settings" buttons.

Light grey background, sections well-spaced.

---

## 76. CANCELLATION POLICY SCREEN

**Prompt:**
Design cancellation policy configuration and display screen. Top app bar: back arrow, "Cancellation Policy" title, edit icon.

**Policy Display Card** (customer-facing view):
- White card with policy icon at top
- "Cancellation Policy" heading (20px, bold)
- Policy text in readable format:
  - Free cancellation period
  - Cancellation fees structure
  - Refund process
  - Non-refundable conditions
- "This policy is shown to customers when booking" note (13px, grey, italic)

**Edit Policy Section**:

1. **Free Cancellation Window**:
   - Radio buttons:
     - Anytime before appointment (no fee)
     - Up to [24] hours before (time input + unit dropdown)
     - Up to [7] days before
     - No free cancellation

2. **Cancellation Fee Structure**:
   - Table/tiered format:
     - More than 7 days before: [0]% fee (input)
     - 3-7 days before: [25]% fee
     - 1-3 days before: [50]% fee
     - Less than 24 hours: [75]% fee
     - No-show: [100]% fee
   - Each row has percentage input

3. **Refund Method**:
   - Radio:
     - Refund to original payment method
     - Store credit only
     - Cash refund at venue
     - No refunds
   - Refund processing time: "[5-7] business days"

4. **Exceptions**:
   - Checkboxes:
     - "Full refund for medical emergencies (with certificate)"
     - "Full refund for business-caused cancellations"
     - "Weather-related cancellations: full refund"
   - Custom exception: Text area

5. **Cancellation Process**:
   - Customer can cancel via (checkboxes): App, Website, Phone call, Email
   - Require cancellation reason (toggle) - if on: show dropdown/text options

6. **Non-Refundable Items**:
   - Checkboxes:
     - Registration fees
     - Service charges
     - Consumable items
   - Text area for additional items

**Policy Templates**:
- Dropdown: "Load template" with options:
  - Flexible (free cancellation anytime)
  - Moderate (24-hour free cancellation)
  - Strict (no refunds)
  - Custom (current settings)

**Legal Text** (collapsible):
- Full T&C text area (for legal compliance)
- "Show full T&C to customers" toggle

**Preview Button**: Shows how policy appears in booking flow

Bottom bar: "Save Policy" button. If changed, show "Policy will apply to new bookings only" warning.

Light grey background.

---

## 77. BLOCKED CUSTOMERS SCREEN

**Prompt:**
Design blocked customers management screen. Top app bar: back arrow, "Blocked Customers" title, search icon.

**Info Card** (top, yellow/orange background):
- Warning icon
- "Blocked customers cannot book appointments or contact you through the app" text (14px)
- "Use this feature carefully" subtext (12px, grey)

**Blocked List**: Vertical scrolling cards (white, rounded 12px):
Each card:
- Left: Customer profile photo (50px circle) or grey placeholder with initials
- Middle section:
  - Customer name (16px, bold)
  - Phone number (14px, grey)
  - Email (14px, grey)
  - Blocked date "Blocked on Jan 15, 2024" (13px, light grey)
  - Reason badge "No-show (3 times)" or "Payment issues" or "Inappropriate behavior" (red pill)
  - Block reason note (if added): Text in grey, italic, 2 lines max
- Right section:
  - "Unblock" button (outlined, blue)
  - Three-dot menu (View history, Edit reason)

**Filter Options**:
- Sort by: Dropdown (Recently blocked, Name A-Z, Most violations)
- Filter by reason: Chips (No-show, Payment, Behavior, Spam, Other)

**Search Bar**: "Search by name, phone, email..."

**Empty State**: If no blocked customers:
- Shield icon (grey)
- "No blocked customers" text
- "Customers you block will appear here"

**Block Customer Modal** (if accessed from customer profile):
- Customer info display (name, photo, phone)
- "Are you sure you want to block [Name]?" warning (18px, bold)
- Reason (dropdown): No-show, Payment issues, Inappropriate behavior, Spam, Other
- Additional notes (text area, optional)
- "They will not be able to book or contact you" info text
- Bottom buttons: "Cancel" (grey) and "Block Customer" (red solid)

**Unblock Confirmation**:
- "Unblock [Name]?" modal
- "They will be able to book and contact you again" text
- "Unblock" button (blue) and "Cancel"

Light grey background.

---

## 78. DATA & STORAGE SCREEN

**Prompt:**
Design data and storage management screen. Top app bar: back arrow, "Data & Storage" title.

**Storage Usage Card** (top, prominent):
- Circular progress indicator showing usage "2.3 GB / 5 GB" (46% used)
- Color: Green if <70%, Orange if 70-90%, Red if >90%
- "Upgrade storage" link (blue) if approaching limit

**Storage Breakdown** (list with bars):
- Each item shows icon, category name, bar (filled based on %), size
  - Photos (image icon, blue) | Bar | "1.2 GB"
  - Videos (video icon, purple) | Bar | "800 MB"
  - Documents (file icon, orange) | Bar | "200 MB"
  - Messages (chat icon, green) | Bar | "100 MB"
  - Cache & Temp (clock icon, grey) | Bar | "50 MB"

**Media Management**:

1. **Auto-Download Settings**:
   - Download media on WiFi only (toggle)
   - Download media on mobile data (toggle)
   - Download quality (dropdown): Original, High, Medium, Low

2. **Media Compression**:
   - Compress photos before upload (toggle)
   - Compression quality (slider: Low - Medium - High)
   - Estimated: "Save up to 60% storage"

3. **Cache Settings**:
   - Cache size limit: "[500] MB"
   - Clear cache button (shows last cleared date)
   - Auto-clear cache: Dropdown (Never, 7 days, 30 days, 90 days)

**Data Management**:

1. **Backup Settings**:
   - Auto backup (toggle) - "Back up to cloud automatically"
   - Backup frequency (dropdown): Daily, Weekly, Monthly
   - Last backup: "2 days ago" (with status icon)
   - "Backup Now" button (blue, outlined)

2. **Export Data**:
   - "Download my data" button
   - "Export includes: Customer data, bookings, messages, media" text
   - "Request takes 24-48 hours" info

3. **Sync Settings**:
   - Sync contacts (toggle)
   - Sync calendar (toggle)
   - Sync across devices (toggle)

**Clean Up Section**:
- "Delete old messages" (specify age: [90] days)
- "Delete old bookings" (completed bookings older than [1] year)
- "Remove unused media" (not linked to any post/service)
- "Clean Up Now" button (shows estimated space recovery)

**Data Usage** (mobile data tracking):
- This month: "450 MB used"
- Graph showing daily usage
- Set data limit: Input + "Warn when approaching limit" toggle

**Privacy**:
- Link to "Download GDPR data report"
- Link to "Request data deletion"

Bottom: "Optimize Storage" button (runs automated cleanup).

Light grey background.

---

## 79. FEEDBACK SUBMISSION SCREEN

**Prompt:**
Design user feedback submission screen. Top app bar: back arrow, "Send Feedback" title.

**Feedback Type Selection** (large icon cards, single select):
- Bug Report (bug icon, red)
- Feature Request (lightbulb icon, blue)
- Improvement Suggestion (star icon, orange)
- Compliment (heart icon, green)
- Other (comment icon, grey)

**Rating Section**:
- "Rate your experience" (16px, bold)
- 5 large stars (interactive, tap to rate)
- Emoji indicators below: 1★=😞 2★=😟 3★=😐 4★=😊 5★=😍

**Feedback Form**:

1. **Subject/Title** (if bug/feature):
   - Input field "Brief summary of your feedback"

2. **Description***:
   - Text area (multiline, 500 chars max)
   - Placeholder based on type:
     - Bug: "Describe what happened and steps to reproduce..."
     - Feature: "Describe the feature you'd like to see..."
     - Improvement: "What can we do better?"
     - Compliment: "We'd love to hear what you enjoyed!"

3. **Category** (dropdown):
   - App Performance
   - User Interface
   - Bookings & Appointments
   - Payments
   - Customer Management
   - Notifications
   - Other

4. **Attachments**:
   - "Add screenshots or files" button
   - Show uploaded files as thumbnails (up to 5)
   - Each with remove X icon

5. **Priority** (if bug):
   - Radio: Low, Medium, High, Critical
   - Helper text explaining each level

6. **Device Info** (auto-collected, shown in grey chip):
   - "Android 13, App v1.2.0" (user can see but not edit)
   - Checkbox: "Include diagnostic data to help us fix issues faster"

**Contact Information**:
- Email (pre-filled from account, editable)
- Checkbox: "I'd like updates on this feedback"

**Previous Feedback** (collapsible):
- Link: "View my previous feedback (5)"
- Shows status of past submissions

**Submit Button** (bottom, blue solid):
- "Send Feedback"
- Disabled (grey) until required fields filled

**Success Modal** (after submission):
- Green checkmark icon
- "Thank you for your feedback!" (22px, bold)
- "We've received your feedback and will review it shortly" text
- Feedback ID "#FB-1234" (for reference)
- "Track Status" button (blue)
- "Submit More Feedback" button (outlined)

Light grey background, friendly and approachable design.

---

## 80. TERMS OF SERVICE SCREEN

**Prompt:**
Design terms of service viewing screen. Top app bar: back arrow, "Terms of Service" title, share icon.

**Header Card**:
- Document icon (large, blue)
- "Terms of Service" heading (24px, bold)
- Last updated: "January 15, 2024" (14px, grey)
- Version: "v2.1" (small badge)

**Document Content** (white card, good readability):
- Scrollable text content with proper formatting
- Section headings (18px, bold, numbered):
  1. Acceptance of Terms
  2. Use of Service
  3. User Accounts
  4. Privacy Policy
  5. Payment Terms
  6. Cancellation & Refunds
  7. Intellectual Property
  8. Limitation of Liability
  9. Termination
  10. Governing Law
  11. Changes to Terms
  12. Contact Us

- Each section:
  - Section number and title (bold)
  - Body text (15px, black, line height 1.6 for readability)
  - Sub-sections with proper indentation
  - Bullet points where applicable

**Reading Progress**:
- Progress bar at top showing scroll progress
- "You've read 45% of the document" (small text, grey)

**Actions** (sticky at bottom or floating):
- "I Accept" button (blue, solid) - if this is during sign-up
- "Download PDF" button (outlined)
- "Email me a copy" link

**Quick Navigation** (collapsible sidebar or floating button):
- Jump to section links:
  - Introduction
  - User Responsibilities
  - Payment & Refunds
  - Privacy
  - Contact

**Highlights** (if user hasn't accepted):
- Key sections highlighted in yellow: Payment terms, Cancellation policy, Liability
- "Important sections" label

**Language Selector** (if available):
- Dropdown at top to switch language

**Footer**:
- "If you have questions about these terms, contact us at legal@business.com"
- "Print" and "Share" options

Clean white background, legal but readable formatting, good typography.

---

## 81. PRIVACY POLICY SCREEN

**Prompt:**
Design privacy policy viewing screen. Similar structure to Terms of Service (#80), but with privacy-focused content:

**Header Card**:
- Shield/lock icon (green, representing security)
- "Privacy Policy" heading (24px, bold)
- Last updated date
- "Your privacy is important to us" tagline (14px, grey)

**Content Sections**:
1. Information We Collect
   - Personal information (expandable)
   - Business information
   - Usage data
   - Device information
2. How We Use Your Information
3. Data Sharing & Disclosure
4. Data Security
5. Your Rights (GDPR Compliance)
   - Right to access
   - Right to deletion
   - Right to correction
   - Data portability
6. Cookies & Tracking
7. Third-Party Services
8. Children's Privacy
9. International Data Transfers
10. Changes to Policy
11. Contact & Data Protection Officer

**Your Data Rights Card** (highlighted section):
- Blue info icon
- "You have the right to:" (bold)
- Bullet list of rights
- "Manage your data" button (blue, links to data settings)
- "Download your data" button (outlined)
- "Delete account" link (red text)

**Cookie Preferences** (interactive section):
- "Manage cookie preferences" button
- Opens modal with toggle switches:
  - Essential cookies (always on, disabled toggle)
  - Analytics cookies (toggle)
  - Marketing cookies (toggle)
  - "Save preferences" button

Same layout, navigation, and features as Terms screen (#80).

---

## 82. DEACTIVATE BUSINESS ACCOUNT SCREEN

**Prompt:**
Design business account deactivation screen. Top app bar: back arrow, "Deactivate Business" title.

**Warning Card** (orange/yellow background):
- Alert triangle icon
- "Are you sure you want to deactivate your business account?" (20px, bold)
- "This action is reversible" (14px, green) - emphasizing it's NOT permanent

**What Happens Section** (white card):
- "When you deactivate:" (16px, bold)
- Checkmarks list (red/orange color):
  - Your business profile will be hidden from customers
  - Customers cannot book appointments or make purchases
  - Your data remains saved and can be restored
  - Active bookings will need to be cancelled or completed
  - You can reactivate anytime within 90 days
  - After 90 days, account may be auto-deleted

**Before You Deactivate** (blue info card):
- Info icon
- "Please consider:" (16px, bold)
- Checklist items:
  - Complete or cancel all pending orders/bookings
  - Inform customers about temporary closure
  - Download any important data or reports
  - Settle pending payments

**Reason for Deactivation** (required):
- Dropdown: "Why are you deactivating?"
  - Taking a break
  - Business temporarily closed
  - Moving to different platform
  - Not getting enough customers
  - Too expensive
  - Technical issues
  - Other (please specify)
- If "Other": Text area appears

**Additional Feedback** (optional):
- Text area: "Help us improve (optional)"
- 500 character limit

**Active Bookings/Orders Alert** (if any):
- Red warning card
- "You have 5 active bookings scheduled"
- List of upcoming bookings (date, customer, service)
- "Cancel all" button or "Contact customers" button
- Cannot proceed unless all handled

**Final Confirmation**:
- Large checkbox: "I understand my account will be hidden and inaccessible"
- "Deactivate Account" button (orange/red, large, requires checkbox)
- Confirmation modal appears when tapped:
  - "Last chance - Deactivate your business?"
  - "Cancel" and "Yes, Deactivate" buttons

**Alternative Suggestion Card** (blue):
- Lightbulb icon
- "Need a break? Try vacation mode instead"
- "Temporarily pause bookings without hiding your profile"
- "Try Vacation Mode" button (blue, outlined)

Light grey background, serious but not scary tone.

---

## 83. DELETE BUSINESS ACCOUNT SCREEN

**Prompt:**
Design permanent account deletion screen. Top app bar: back arrow, "Delete Business Account" title (red).

**DANGER ZONE Banner** (red background, full width):
- Skull/trash icon (white)
- "PERMANENT DELETION" (white, bold, caps)
- "This action cannot be undone" (white)

**Warning Card** (red background):
- Stop sign icon
- "Permanently Delete Your Business Account?" (22px, bold, black)
- "THIS ACTION IS PERMANENT AND CANNOT BE UNDONE" (14px, red, bold)

**What You'll Lose** (white card with red border):
- "When you delete your account:" (16px, bold)
- X icons (red) next to each:
  - All business data will be permanently deleted
  - Customer database and history will be lost
  - All photos, reviews, and ratings will be removed
  - Active subscriptions will be cancelled (no refund)
  - You cannot recover your business profile
  - Your business name may become available to others
  - All team member access will be revoked
  - Financial records will be deleted after legal retention period

**Legal Obligations** (blue info card):
- Info icon
- "Before deleting:" (16px, bold)
  - Complete all active orders/bookings
  - Settle all pending payments
  - Download tax/financial records
  - Inform customers and staff
  - Cancel active subscriptions
  - Review legal obligations (link to terms)

**Final Data Download** (white card):
- "Last chance to download your data"
- File icons showing what's included:
  - Customer database
  - Booking history
  - Financial records
  - Media files
- "Download All Data" button (blue, solid) - must be clicked before deletion enabled

**Deletion Reason*** (required):
- Dropdown: "Why are you deleting?" (similar to deactivate, but more serious options)
- Text area for detailed feedback

**Verification Steps**:
1. **Confirm your identity**:
   - Phone verification: "Enter code sent to +91 98765 43210"
   - 6-digit OTP input boxes
   - "Resend code" link

2. **Type to confirm**:
   - "Type 'DELETE' to confirm" (bold)
   - Text input field (must match exactly)
   - Case-sensitive warning

3. **Final checkbox**:
   - Large checkbox: "I understand this is permanent and all my data will be deleted"

**Alternative Offered** (green card):
- Heart icon
- "We'll miss you! Are you sure you don't want to:"
- Two buttons:
  - "Deactivate Instead" (green, outlined)
  - "Contact Support" (green, outlined)

**Delete Button** (bottom):
- "Permanently Delete Account" (large, red, solid)
- Disabled (grey) until all verifications complete
- Enabled (red) after verifications

**Final Confirmation Modal**:
- "FINAL WARNING" (red, bold)
- "This is your last chance. Are you absolutely sure?"
- Account stats: "You'll lose: 234 customers, 1,250 bookings, 4.5★ rating"
- Two buttons:
  - "No, Keep My Account" (blue, solid, larger)
  - "Yes, Delete Forever" (red, outlined, smaller)

**Processing Screen** (after confirmation):
- Loading spinner
- "Deleting your account..."
- "This may take a moment"

**Deletion Complete**:
- Checkmark icon (grey, not green)
- "Your account has been deleted" (22px)
- "We're sorry to see you go" (14px, grey)
- "Your data will be completely removed within 30 days as per legal requirements"
- "Create New Business" button (blue)
- "Go to Homepage" button (outlined)

Dark red accents, very serious tone, multiple confirmation steps.

---

## 84. INVOICE/RECEIPT SCREEN

**Prompt:**
Design invoice viewing and management screen. Top app bar: back arrow, "Invoice #INV-1234" title, download icon, share icon, print icon.

**Invoice Header Card** (white, professional):
- Top section:
  - Left: Business logo (60px) + Business name, address, GSTIN, Phone
  - Right: "INVOICE" text (large, bold, blue)
- Invoice details row:
  - Invoice number "INV-1234"
  - Invoice date "Jan 15, 2024"
  - Due date "Jan 30, 2024" (if applicable)
  - Payment status badge: "Paid" (green), "Pending" (orange), "Overdue" (red), "Cancelled" (grey)

**Bill To / Customer Details** (white card):
- Customer name (bold)
- Phone number
- Email
- Address (if applicable)
- Customer GSTIN (if B2B)

**Items/Services Table**:
- Table with columns:
  - #
  - Description (item/service name)
  - HSN/SAC code (if applicable)
  - Qty
  - Rate
  - Tax rate (%)
  - Amount
- Each row shows service/product details
- Alternating row colors for readability

**Calculation Section** (right-aligned):
- Subtotal: ₹X,XXX
- Discount (if any): -₹XXX
- CGST @ 9%: ₹XXX
- SGST @ 9%: ₹XXX
  OR IGST @ 18%: ₹XXX
- Total: ₹X,XXX (large, bold, blue)
- Amount in words: "Rupees Twelve Thousand Five Hundred Only"

**Payment Information**:
- Payment method: "UPI"
- Payment date: "Jan 15, 2024, 2:30 PM"
- Transaction ID: "TXN123456789"
- Payment status: "Success" with green checkmark

**Terms & Conditions** (collapsible):
- Small text showing T&C
- Return/exchange policy
- Cancellation policy

**Bank Details** (if payment pending):
- Account name
- Account number
- IFSC code
- UPI ID
- QR code for payment

**Footer**:
- "Thank you for your business!"
- Business signature (if uploaded)
- "Computer generated invoice, signature not required" text

**Action Buttons** (bottom or floating):
- Download PDF (blue)
- Share Invoice (WhatsApp, Email, Message icons)
- Print Invoice
- Mark as Paid (if pending)
- Send Payment Reminder (if pending)

**Invoice List Screen** (separate):
- Search bar: "Search invoices..."
- Filters: Status (All, Paid, Pending, Overdue), Date range
- Sort: Date, Amount, Status
- List of invoice cards:
  - Invoice number + date
  - Customer name
  - Amount (bold, blue)
  - Status badge
  - Quick actions: View, Download, Share

Professional design, print-ready formatting, complies with GST invoice requirements.

---

## 85. QR CODE PAYMENT SCREEN

**Prompt:**
Design QR code payment acceptance screen. Top app bar: back arrow, "Receive Payment" title.

**Amount Input Card** (prominent, top):
- Large currency symbol "₹"
- Amount input (very large text, 48px) placeholder "0"
- Numeric keypad built-in OR standard input that opens number keyboard
- "Add Note" link (opens text input for payment description)

**Payment Method Tabs**:
- QR Code (default, active)
- Payment Link
- Card Reader (if integrated)

**QR Code Display** (large, centered):
- Business name at top
- Large QR code (300×300px minimum)
- "Scan to pay [Business Name]" text below
- Amount to be paid "₹1,500" shown prominently below QR
- Supported apps icons: GPay, PhonePe, Paytm, BHIM (small logos)

**QR Code Options**:
- Download QR button (saves as PNG for printing)
- Share QR (sends image via WhatsApp, Email)
- Print QR (generates printable version with business details)

**Dynamic vs Static QR**:
- Toggle: "Dynamic QR" (amount changes each time) vs "Static QR" (fixed for display)
- If static: QR remains same, customer enters amount
- If dynamic: QR includes amount, regenerates each transaction

**Payment Status** (appears after scanning):
- Waiting state: Loading spinner "Waiting for payment..."
- Success state: Green checkmark, "Payment Received! ₹1,500", Confetti animation
- Failed state: Red X, "Payment failed", "Try Again" button

**Transaction History** (bottom section):
- "Recent QR Payments" (14px, bold)
- List of recent transactions:
  - Time "2 min ago"
  - Amount "₹1,500" (green if successful)
  - Customer UPI ID (masked): "user@upi"
  - Transaction ID
  - Status icon

**Alternative Payment Options**:
- "Payment Link" tab content:
  - Generate payment link button
  - Link preview: "pay.yourbusiness.com/xyz123"
  - Copy link, Share link buttons
  - Valid for: [24] hours (configurable)

**Settings** (gear icon menu):
- Payment sound notification (toggle)
- Auto-generate receipt (toggle)
- Ask for customer phone (toggle) - to send receipt
- Default payment note (text input)

**Receipt Options** (after successful payment):
- "Send Receipt" button:
  - SMS
  - WhatsApp
  - Email (asks for customer email)
- Print receipt
- Save to transactions

Clean, minimal design, large QR code, clear amount display, works in bright/outdoor conditions.

---

## 86. COUPON/DISCOUNT MANAGEMENT SCREEN

**Prompt:**
Design coupons and discounts management screen. Top app bar: "Coupons & Offers" title, filter icon, add (+) icon.

**Active/Inactive/Expired tabs**: Horizontal tabs with count badges.

**Coupon Cards**: Vertical scrolling list
Each card (white, rounded 12px, colorful left border):
- Top section:
  - Coupon code "WELCOME20" (large, bold, blue, copyable)
  - Copy icon button
  - Status badge: "Active" (green), "Scheduled" (blue), "Expired" (grey)
- Middle section:
  - Offer description "Get 20% off on your first booking" (16px)
  - Discount badge: "20% OFF" or "₹500 OFF" (large pill, colored)
  - Valid dates: "Jan 15 - Jan 31, 2024" with calendar icon
  - Usage stats: "Used 45/100 times" with progress bar
  - Minimum order: "Min order ₹1,000" (if applicable)
- Bottom section:
  - "Edit" button, "Duplicate" button, "Deactivate" toggle, three-dot menu

**Quick Stats Header**:
- Total coupons: 12
- Active: 8
- Redeemed today: 23
- Revenue from coupons: ₹12,500

**Filters**:
- Discount type: Percentage, Fixed amount, BOGO, Free shipping
- Status: Active, Scheduled, Expired
- Usage: Unused, Partially used, Fully used

Light grey background. Floating action button (+) to create new coupon.

---

## 87. COUPON/DISCOUNT CREATE/EDIT FORM

**Prompt:**
Design coupon creation form. Top app bar: back arrow, "Create Coupon" title, save icon.

White form with sections:

1. **Coupon Code***:
   - Text input (uppercase auto-convert)
   - "Generate code" button (creates random code like "SAVE25XYZ")
   - Validation: "Check availability" (shows checkmark if unique)

2. **Discount Type***:
   - Radio buttons:
     - Percentage off (%)
     - Fixed amount off (₹)
     - Buy X Get Y free
     - Free shipping/delivery
   - Based on selection, show relevant inputs:
     - Percentage: Slider or input (1-100%)
     - Fixed: Rupee input
     - BXGY: "Buy [X] items, Get [Y] free"

3. **Discount Value***:
   - Number input (percentage or amount)
   - If percentage: Max discount cap "Up to ₹[500]" (optional)

4. **Minimum Requirements**:
   - Minimum order value: ₹input (optional)
   - Minimum items: Number input (optional)

5. **Validity Period***:
   - Start date & time (date time picker)
   - End date & time (date time picker)
   - Or: "Valid for [7] days from first use"

6. **Usage Limits**:
   - Total usage limit: "[100] times" (optional, blank = unlimited)
   - Per customer limit: "[1] time per customer"
   - Progress bar showing current usage (if editing)

7. **Applicable To**:
   - Radio: All products/services, Specific categories, Specific items
   - If specific: Multi-select dropdown or search

8. **Customer Eligibility**:
   - Radio:
     - All customers
     - New customers only
     - Existing customers only
     - Specific customer segments (VIP, Members, etc.)

9. **Combine with Other Offers**:
   - Toggle: "Can be combined with other promotions"
   - Checkbox: "Cannot be used with items already on sale"

10. **Display Options**:
    - Auto-apply (toggle): "Apply automatically if conditions met"
    - Show on profile (toggle): "Display in promotions section"
    - Promoted (toggle): "Show banner on home screen"

11. **Description & Terms**:
    - Public description (text area): What customers see
    - Terms & conditions (text area): Fine print

12. **Internal Notes**:
    - Text area: Notes for staff only (not visible to customers)

**Preview Section**: Shows how coupon will appear to customers (banner, card, code).

Bottom bar: "Save as Draft", "Schedule", "Activate Now" buttons.

---

## 88. STAFF ROLES & PERMISSIONS SCREEN

**Prompt:**
Design role-based access control screen. Top app bar: back arrow, "Roles & Permissions" title, add role (+) icon.

**Default Roles Cards**:
Each role card (white, rounded 12px):
- Role icon (badge/shield icon with color)
- Role name "Manager" (18px, bold)
- Members count "3 staff members" with profile photo overlap
- Description "Can manage everything except business settings"
- Permissions summary: "Full Access: Bookings, Customers, Staff | No Access: Settings, Billing"
- "Edit" button, "View members" link

**Roles List**:
1. **Owner/Admin** (gold badge, locked):
   - "Full access to everything"
   - Cannot be edited or deleted
   - Only one owner

2. **Manager** (blue badge):
   - "Manage operations and staff"
   - Editable permissions

3. **Staff** (green badge):
   - "Basic access to perform services"
   - Limited permissions

4. **View Only** (grey badge):
   - "Can view data but cannot make changes"
   - Read-only access

5. **Custom Roles** (user-created, purple badge):
   - Custom names and permissions

**Create/Edit Role Modal**:
- Role name* (input)
- Role description (text area)
- Choose role color (color picker)

**Permissions Matrix** (checkboxes):

**Bookings & Appointments**:
- ☑ View bookings
- ☑ Create bookings
- ☑ Edit bookings
- ☑ Cancel bookings
- ☑ Manage calendar
- ☐ Access all staff bookings

**Customers**:
- ☑ View customers
- ☑ Add customers
- ☑ Edit customer details
- ☑ Delete customers
- ☐ View customer history
- ☑ Send messages

**Services & Products**:
- ☑ View services/products
- ☐ Add/edit services
- ☐ Set prices
- ☐ Manage inventory

**Financial**:
- ☑ Accept payments
- ☑ View transactions
- ☐ View reports
- ☐ Manage pricing
- ☐ Access financial reports
- ☐ Issue refunds

**Team Management**:
- ☐ View all staff
- ☐ Add staff members
- ☐ Edit staff details
- ☐ Manage schedules
- ☐ View staff performance

**Business Settings**:
- ☐ Edit business profile
- ☐ Manage business hours
- ☐ Configure integrations
- ☐ Access billing
- ☐ Manage subscriptions

**Marketing**:
- ☑ Create posts
- ☑ Send promotions
- ☐ Manage coupons
- ☐ View analytics

**System**:
- ☑ View activity logs
- ☐ Export data
- ☐ Manage roles (create/edit roles)

**Permission Presets**: Buttons to quickly set:
- "Full Access" (checks all)
- "Read Only" (view permissions only)
- "Standard Staff" (common staff permissions)

**Assign Members**:
- Search and select staff members to assign this role
- Shows list of assigned members with remove option

Bottom bar: "Save Role" button.

**Warning Modal** (when editing role):
- "Changes will affect X staff members with this role"
- "Continue" or "Cancel"

Light grey background, clear permission organization.

---

## 89. CUSTOMER FEEDBACK/REVIEW RESPONSE SCREEN

**Prompt:**
Design a screen for business to view and respond to customer feedback. Top app bar: "Customer Feedback" title, filter icon, export icon.

**Feedback Score Card** (top, prominent gradient):
- Large satisfaction score "4.8/5.0" (center)
- Star icons (4.8 stars filled)
- "Based on 234 reviews this month" (text below)
- Trend indicator: "+0.3 from last month" (green, up arrow)

**Quick Filters Chips**:
- All Feedback
- Positive (green) with count "(189)"
- Neutral (orange) with count "(30)"
- Negative (red) with count "(15)"
- Unanswered (blue) with badge "12 new"

**Sort Dropdown**: Most Recent, Oldest First, Highest Rated, Lowest Rated, Unanswered First

**Feedback Cards**: Vertical scrolling list
Each card (white, rounded 12px, colored left border based on rating):
- Top row:
  - Customer profile photo (40px circle) + name
  - Rating stars (colored: 5=gold, 4=green, 3=orange, 1-2=red)
  - Time "3 days ago" (right-aligned)
- Service/Product name "Haircut & Styling" (14px, grey, with service icon)
- Feedback text (15px, black, good line height)
  - If long: Show 3 lines with "Read more" link
- If photos attached: Horizontal scrollable thumbnails (80×80px)
- Business response section (if replied):
  - Indented with light blue background
  - "Response from [Business Name]" (13px, bold)
  - Response text
  - Response date "Replied 2 days ago"
- Bottom action row:
  - "Reply" button (blue, outlined) if not replied
  - "Edit Reply" if already replied
  - "Mark as Helpful" (thumbs up icon)
  - "Report" (flag icon)
  - Three-dot menu

**Analytics Card** (collapsible):
- Most mentioned keywords: Tag cloud (larger = more frequent)
  - "Great service", "Clean place", "Friendly staff", "Expensive"
- Sentiment trend: Line graph showing positive/negative over time
- Response rate: "You've responded to 85% of reviews" with progress bar

**Quick Response Templates** (when replying):
- Positive: "Thank you so much for your kind words!"
- Neutral: "Thanks for your feedback. We'll work on improving."
- Negative: "We apologize for the inconvenience. We'd like to make it right."
- Custom: User can write own response

**Reply Modal** (bottom sheet):
- Original review shown at top (grey background)
- Text area for response (300 chars)
- Character counter
- Template selector
- "Post Response" button (blue)
- Note: "Responses are publicly visible"

**Bulk Actions** (when items selected):
- Mark as resolved
- Export selected
- Send thank you message

Light grey background, empathetic tone in UI copy.

---

## 90. BUSINESS VERIFICATION FLOW

**Prompt:**
Design business verification application screen. Top app bar: back arrow, "Get Verified" title, help icon.

**Verification Badge Preview**:
- Large blue checkmark badge icon
- "Verified Business" text
- "Increase trust and get featured in search results"

**Benefits Card** (white, with checkmarks):
- "Why get verified?" (16px, bold)
- ✓ Build customer trust
- ✓ Higher search ranking
- ✓ Featured badge on profile
- ✓ Access to premium features
- ✓ Priority support

**Requirements** (checklist):
- ✓ Complete business profile (green checkmark)
- ✓ Add business photos (green checkmark)
- ✓ Minimum 10 bookings completed
- ✗ Business license/registration document (red X - incomplete)
- ✓ Valid phone number verified
- ✗ Physical address verified

**Verification Application Form**:

1. **Business Registration**:
   - Registration type (dropdown): LLC, Sole Proprietorship, Partnership, Corporation, etc.
   - Registration number* (input)
   - Registration document upload* (PDF/Image, max 5MB)
   - Issuing authority (input)

2. **Business License** (if applicable):
   - License number
   - License type (Trade license, Professional license, etc.)
   - License document upload
   - Expiry date (date picker)

3. **Identity Verification**:
   - Owner/Authorized person name* (must match registration)
   - ID Proof type (dropdown): Aadhaar, Passport, Driver's License
   - ID number*
   - ID document upload* (front and back)

4. **Address Verification**:
   - Proof of address type (dropdown): Utility bill, Lease agreement, Property tax receipt
   - Document upload*
   - Document date (must be within 3 months)
   - "Address matches business address" checkbox

5. **Tax Information**:
   - GST number (if applicable, auto-checks GSTIN format)
   - GST certificate upload (optional)
   - PAN number*
   - PAN card upload

6. **Contact Verification**:
   - Business phone* (must be verified)
   - Business email* (must be verified)
   - Website URL (optional, validates format)
   - Physical verification: "Schedule visit" button (for premium verifications)

7. **Additional Information**:
   - Years in business (number)
   - Number of employees (number or range)
   - Business hours (must be filled in settings)
   - Social media profiles (Facebook, Instagram URLs for cross-verification)

**Document Upload Guidelines**:
- Clear icon showing document requirements
- "Documents must be:"
  - Clear and readable
  - Not expired
  - Original or certified copies
  - Matching business name

**Verification Fee** (if applicable):
- Fee amount "₹999 one-time verification fee"
- "Pay Now" button
- "100% refundable if verification fails"

**Submission**:
- "I certify all information is accurate" checkbox*
- "Submit for Verification" button (blue, large)

**After Submission**:
- Confirmation screen:
  - Hourglass icon
  - "Application Submitted"
  - Application ID "#VER-12345"
  - "We'll review your application within 3-5 business days"
  - "Track Status" button

**Status Tracking**:
- Progress tracker:
  1. Application Submitted ✓
  2. Documents Under Review (current, blue)
  3. Physical Verification (if required)
  4. Verification Complete

- Status updates via notifications
- "Need help?" button to contact support

**If Rejected**:
- Red X icon
- "Verification Incomplete"
- Reasons listed
- "Resubmit Application" button
- No additional fee for resubmission

**If Approved**:
- Green checkmark with confetti animation
- "Congratulations! You're Verified"
- Verified badge now shows on profile
- "Share Achievement" button (social media)

Professional, official design, clear instructions, secure document upload.

---

## ADDITIONAL SCREENS SUMMARY

**Total Screens Now Documented**: 90+ comprehensive UI screens covering:
- Complete onboarding (8 screens)
- Dashboard variants for all 7 business types
- Category-specific management (15+ screens):
  - Services, Staff, Courses, Vehicles, Properties, Memberships
- Customer management (Inquiries, Feedback, Blocked customers)
- Business operations (Hours, Holidays, Delivery areas, Policies)
- Financial (Tax, Invoices, QR payments, Coupons)
- Content management (Posts, Gallery, Reviews)
- Settings & Configuration (15+ screens)
- Account management (Deactivate, Delete)
- Legal & Compliance (Terms, Privacy, Verification)
- System states (Loading, Errors, Empty, Success)

---

**COMPLETE DESIGN SYSTEM**

This comprehensive design document now covers every screen and user flow in the business profile management application, from initial onboarding through daily operations to account deletion, with consistent design language, detailed specifications, and industry best practices.

Perfect for:
- AI image generation prompts
- Designer briefings
- Development specifications
- Product documentation
- UX/UI consistency guidelines

All 90+ screens maintain visual consistency with the established design system (blue accent colors, 12px radius, clean typography, professional aesthetic).

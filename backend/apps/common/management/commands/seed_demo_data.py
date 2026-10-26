from datetime import time
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.accounts.models import Address, User, UserRole
from apps.delivery import services as delivery_services
from apps.delivery.models import DeliveryPartner, DeliveryPartnerStatus, VehicleType
from apps.menu.models import Food, FoodAddon, FoodCategory, FoodReview, FoodType, FoodVariant
from apps.orders import services as order_services
from apps.orders.models import Order, OrderStatus, Review
from apps.restaurants.models import (
    DayOfWeek,
    Restaurant,
    RestaurantApprovalStatus,
    RestaurantBusinessHours,
    RestaurantCategory,
    RestaurantImage,
)

DEMO_PASSWORD = "DemoPass123!"


class Command(BaseCommand):
    help = "Seeds rich demo data (restaurants, menus, customers, delivery partners, orders in every status) for UI/UX testing across all four apps. Safe to re-run."

    def handle(self, *args, **options):
        with transaction.atomic():
            owners = self._create_owners()
            restaurants = self._create_restaurants(owners)
            self._create_categories(restaurants)
            self._create_menus(restaurants)
            customers = self._create_customers()
            partners = self._create_delivery_partners()
            orders = self._create_orders(restaurants, customers, partners)
            self._create_reviews(orders)

        self.stdout.write(self.style.SUCCESS("\n=== Demo data seeded ==="))
        self._print_credentials(owners, customers, partners)

    # ------------------------------------------------------------------
    def _get_or_create_user(self, *, phone_number, email, full_name, role, **extra):
        user, created = User.objects.get_or_create(
            phone_number=phone_number,
            defaults={
                "email": email,
                "full_name": full_name,
                "role": role,
                "is_phone_verified": True,
                "is_email_verified": True,
                **extra,
            },
        )
        if created:
            user.set_password(DEMO_PASSWORD)
            user.save(update_fields=["password"])
            self.stdout.write(f"  + user {full_name} ({role})")
        return user

    # ------------------------------------------------------------------
    def _create_owners(self):
        specs = [
            ("9800000001", "owner.spicegarden@garuda.test", "Priya Raman"),
            ("9800000002", "owner.punjabitadka@garuda.test", "Gurpreet Singh"),
            ("9800000003", "owner.pizzapoint@garuda.test", "Arjun Mehta"),
            ("9800000004", "owner.seabreeze@garuda.test", "Fatima Khan"),
            ("9800000005", "owner.biryanihouse@garuda.test", "Karthik Iyer"),
        ]
        return [
            self._get_or_create_user(phone_number=p, email=e, full_name=n, role=UserRole.RESTAURANT_OWNER)
            for p, e, n in specs
        ]

    # ------------------------------------------------------------------
    def _create_restaurant(self, owner, *, name, description, cuisine_tags, address_line, city, lat, lng,
                            approval_status=RestaurantApprovalStatus.APPROVED, is_accepting_orders=True,
                            cover_image_url="", open_time=time(0, 0), close_time=time(23, 59)):
        restaurant, created = Restaurant.objects.get_or_create(
            owner=owner,
            name=name,
            defaults={
                "description": description,
                "cuisine_tags": cuisine_tags,
                "address_line": address_line,
                "city": city,
                "latitude": Decimal(str(lat)),
                "longitude": Decimal(str(lng)),
                "is_active": True,
                "is_accepting_orders": is_accepting_orders,
                "approval_status": approval_status,
                "cover_image_url": cover_image_url,
            },
        )
        if not created:
            return restaurant

        self.stdout.write(f"  + restaurant {name} ({approval_status})")
        RestaurantImage.objects.create(restaurant=restaurant, image_url=cover_image_url, is_primary=True)
        for day in DayOfWeek.values:
            RestaurantBusinessHours.objects.create(
                restaurant=restaurant, day_of_week=day, opening_time=open_time, closing_time=close_time
            )
        if approval_status == RestaurantApprovalStatus.APPROVED:
            from django.utils import timezone
            restaurant.approved_at = timezone.now()
            restaurant.save(update_fields=["approved_at"])
        return restaurant

    def _create_restaurants(self, owners):
        o1, o2, o3, o4, o5 = owners
        r = {}
        r["spice_garden"] = self._create_restaurant(
            o1, name="Spice Garden", description="Authentic South Indian tiffin & meals.",
            cuisine_tags=["South Indian", "Tiffin"], address_line="12 Big Street", city="Karaikal",
            lat=10.9254, lng=79.8380,
            cover_image_url="https://images.unsplash.com/photo-1630383249896-424e482df921?w=800",
        )
        r["punjabi_tadka"] = self._create_restaurant(
            o2, name="Punjabi Tadka", description="North Indian curries, tandoor & breads.",
            cuisine_tags=["North Indian", "Punjabi"], address_line="45 Market Road", city="Karaikal",
            lat=10.9200, lng=79.8420, open_time=time(11, 0), close_time=time(23, 0),
            cover_image_url="https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800",
        )
        r["pizza_point"] = self._create_restaurant(
            o3, name="Pizza Point", description="Wood-fired pizzas & fast food.",
            cuisine_tags=["Italian", "Fast Food"], address_line="8 Beach Road", city="Karaikal",
            lat=10.9280, lng=79.8360, open_time=time(10, 0), close_time=time(21, 0),
            cover_image_url="https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800",
        )
        r["sea_breeze"] = self._create_restaurant(
            o4, name="Sea Breeze Cafe", description="All-day breakfast & continental cafe fare.",
            cuisine_tags=["Cafe", "Continental"], address_line="2 Promenade Street", city="Karaikal",
            lat=10.9300, lng=79.8400, approval_status=RestaurantApprovalStatus.PENDING,
            cover_image_url="https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800",
        )
        r["biryani_house"] = self._create_restaurant(
            o5, name="Biryani House", description="Slow-cooked dum biryanis.",
            cuisine_tags=["Biryani", "Mughlai"], address_line="19 Anna Nagar", city="Karaikal",
            lat=10.9230, lng=79.8330, is_accepting_orders=False,
            cover_image_url="https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800",
        )
        return r

    # ------------------------------------------------------------------
    def _create_categories(self, r):
        specs = [
            ("South Indian", "https://images.unsplash.com/photo-1630383249896-424e482df921?w=200", ["spice_garden"]),
            ("North Indian", "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=200", ["punjabi_tadka"]),
            ("Fast Food", "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=200", ["pizza_point"]),
            ("Biryani", "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=200", ["biryani_house"]),
            ("Cafe", "https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=200", ["sea_breeze"]),
            ("Pure Veg", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=200", ["spice_garden", "sea_breeze"]),
        ]
        for name, icon_url, restaurant_keys in specs:
            category, created = RestaurantCategory.objects.get_or_create(name=name, defaults={"icon_url": icon_url})
            if created:
                self.stdout.write(f"  + category {name}")
            for key in restaurant_keys:
                r[key].categories.add(category)

    # ------------------------------------------------------------------
    def _add_food(self, restaurant, category, *, name, price, food_type, image_url="", description="", is_bestseller=False,
                   is_available=True, variants=None, addons=None):
        food, created = Food.objects.get_or_create(
            restaurant=restaurant,
            name=name,
            defaults={
                "category": category,
                "description": description,
                "base_price": Decimal(str(price)),
                "food_type": food_type,
                "is_bestseller": is_bestseller,
                "is_available": is_available,
                "image_url": image_url,
            },
        )
        if not created:
            # Re-running the seed still backfills a missing/changed photo on existing rows.
            if food.image_url != image_url:
                food.image_url = image_url
                food.save(update_fields=["image_url"])
            return food
        for v_name, v_price, is_default in variants or []:
            FoodVariant.objects.create(food=food, name=v_name, price=Decimal(str(v_price)), is_default=is_default)
        for a_name, a_price in addons or []:
            FoodAddon.objects.create(food=food, name=a_name, price=Decimal(str(a_price)))
        return food

    def _create_menus(self, r):
        # Spice Garden
        rest = r["spice_garden"]
        tiffin = FoodCategory.objects.get_or_create(restaurant=rest, name="Tiffin", defaults={"sort_order": 1})[0]
        mains = FoodCategory.objects.get_or_create(restaurant=rest, name="Main Course", defaults={"sort_order": 2})[0]
        bev = FoodCategory.objects.get_or_create(restaurant=rest, name="Beverages", defaults={"sort_order": 3})[0]
        self._add_food(rest, tiffin, name="Idli (2 pcs)", price=40, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=600")
        self._add_food(rest, tiffin, name="Masala Dosa", price=60, food_type=FoodType.VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1630383249896-424e482df921?w=600",
                        variants=[("Plain", 50, False), ("Masala", 60, True), ("Ghee Roast", 75, False)])
        self._add_food(rest, tiffin, name="Pongal", price=50, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=600")
        self._add_food(rest, mains, name="Sambar Rice", price=80, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600")
        self._add_food(rest, mains, name="Chicken Chettinad", price=180, food_type=FoodType.NON_VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600")
        self._add_food(rest, bev, name="Filter Coffee", price=25, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600")

        # Punjabi Tadka
        rest = r["punjabi_tadka"]
        starters = FoodCategory.objects.get_or_create(restaurant=rest, name="Starters", defaults={"sort_order": 1})[0]
        mains = FoodCategory.objects.get_or_create(restaurant=rest, name="Main Course", defaults={"sort_order": 2})[0]
        breads = FoodCategory.objects.get_or_create(restaurant=rest, name="Breads", defaults={"sort_order": 3})[0]
        self._add_food(rest, starters, name="Paneer Tikka", price=150, food_type=FoodType.VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600")
        self._add_food(rest, starters, name="Chicken Seekh Kebab", price=180, food_type=FoodType.NON_VEG,
                        image_url="https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600")
        self._add_food(rest, mains, name="Butter Chicken", price=220, food_type=FoodType.NON_VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600",
                        variants=[("Half", 220, True), ("Full", 380, False)],
                        addons=[("Extra Gravy", 30), ("Extra Butter", 20)])
        self._add_food(rest, mains, name="Dal Makhani", price=140, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=600")
        self._add_food(rest, mains, name="Paneer Butter Masala", price=160, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600")
        self._add_food(rest, breads, name="Butter Naan", price=40, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600")
        self._add_food(rest, breads, name="Tandoori Roti", price=25, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1601924994987-69e26d50dc26?w=600")

        # Pizza Point
        rest = r["pizza_point"]
        pizza = FoodCategory.objects.get_or_create(restaurant=rest, name="Pizza", defaults={"sort_order": 1})[0]
        sides = FoodCategory.objects.get_or_create(restaurant=rest, name="Sides", defaults={"sort_order": 2})[0]
        bev = FoodCategory.objects.get_or_create(restaurant=rest, name="Beverages", defaults={"sort_order": 3})[0]
        self._add_food(rest, pizza, name="Margherita", price=199, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600",
                        variants=[("Regular", 199, True), ("Medium", 349, False), ("Large", 499, False)],
                        addons=[("Extra Cheese", 50), ("Extra Toppings", 40)])
        self._add_food(rest, pizza, name="Farmhouse", price=249, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1595854341625-f33ee10dbf94?w=600")
        self._add_food(rest, pizza, name="Chicken Pepperoni", price=299, food_type=FoodType.NON_VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1628840042765-356cda07504e?w=600")
        self._add_food(rest, sides, name="Garlic Bread", price=99, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=600")
        self._add_food(rest, sides, name="French Fries", price=89, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600")
        self._add_food(rest, bev, name="Coke (500ml)", price=49, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600")

        # Sea Breeze Cafe (pending approval — still gets a menu)
        rest = r["sea_breeze"]
        breakfast = FoodCategory.objects.get_or_create(restaurant=rest, name="All Day Breakfast", defaults={"sort_order": 1})[0]
        bev = FoodCategory.objects.get_or_create(restaurant=rest, name="Beverages", defaults={"sort_order": 2})[0]
        self._add_food(rest, breakfast, name="Pancakes", price=150, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600")
        self._add_food(rest, breakfast, name="Avocado Toast", price=180, food_type=FoodType.VEGAN,
                        image_url="https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=600")
        self._add_food(rest, bev, name="Cappuccino", price=120, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600")
        self._add_food(rest, bev, name="Iced Tea", price=90, food_type=FoodType.VEGAN,
                        image_url="https://images.unsplash.com/photo-1499638673689-79a0b5115d87?w=600")

        # Biryani House (paused — not accepting orders)
        rest = r["biryani_house"]
        biryani = FoodCategory.objects.get_or_create(restaurant=rest, name="Biryani", defaults={"sort_order": 1})[0]
        sides = FoodCategory.objects.get_or_create(restaurant=rest, name="Sides", defaults={"sort_order": 2})[0]
        self._add_food(rest, biryani, name="Chicken Biryani", price=220, food_type=FoodType.NON_VEG, is_bestseller=True,
                        image_url="https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600",
                        variants=[("Half", 220, True), ("Full", 400, False)])
        self._add_food(rest, biryani, name="Mutton Biryani", price=280, food_type=FoodType.NON_VEG, is_available=False,
                        image_url="https://images.unsplash.com/photo-1567337710282-00832b415979?w=600")
        self._add_food(rest, biryani, name="Veg Biryani", price=160, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1631515243349-e0cb75fb8d3a?w=600")
        self._add_food(rest, sides, name="Raita", price=30, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1631292784640-2b24be784d5d?w=600")
        self._add_food(rest, sides, name="Mirchi Ka Salan", price=25, food_type=FoodType.VEG,
                        image_url="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600")

    # ------------------------------------------------------------------
    def _create_customers(self):
        specs = [
            ("9800001001", "deepa@garuda.test", "Deepa Nair"),
            ("9800001002", "ramesh@garuda.test", "Ramesh Kumar"),
            ("9800001003", "sneha@garuda.test", "Sneha Pillai"),
        ]
        customers = []
        for phone, email, name in specs:
            user = self._get_or_create_user(phone_number=phone, email=email, full_name=name, role=UserRole.CUSTOMER)
            if not user.addresses.exists():
                Address.objects.create(
                    user=user, label="home", address_line1=f"{name.split()[0]} House, 7th Cross",
                    city="Karaikal", state="Puducherry", pincode="609602",
                    latitude=Decimal("10.9245"), longitude=Decimal("79.8375"), is_default=True,
                )
                Address.objects.create(
                    user=user, label="work", address_line1="Tech Park, Beach Road",
                    city="Karaikal", state="Puducherry", pincode="609602",
                    latitude=Decimal("10.9290"), longitude=Decimal("79.8355"), is_default=False,
                )
            customers.append(user)
        return customers

    # ------------------------------------------------------------------
    def _create_delivery_partners(self):
        specs = [
            ("9800002001", "rajesh.rider@garuda.test", "Rajesh Kumar", VehicleType.MOTORCYCLE, True, DeliveryPartnerStatus.ONLINE),
            ("9800002002", "vijay.rider@garuda.test", "Vijay Anand", VehicleType.SCOOTER, True, DeliveryPartnerStatus.OFFLINE),
            ("9800002003", "suresh.rider@garuda.test", "Suresh Babu", VehicleType.BICYCLE, False, DeliveryPartnerStatus.OFFLINE),
            ("9800002004", "manoj.rider@garuda.test", "Manoj Verma", VehicleType.MOTORCYCLE, True, DeliveryPartnerStatus.ONLINE),
        ]
        partners = {}
        for phone, email, name, vehicle, verified, status in specs:
            user = self._get_or_create_user(phone_number=phone, email=email, full_name=name, role=UserRole.DELIVERY_PARTNER)
            partner, created = DeliveryPartner.objects.get_or_create(
                user=user,
                defaults={
                    "vehicle_type": vehicle,
                    "vehicle_number": f"PY01AB{phone[-4:]}",
                    "license_number": f"PY01202300{phone[-5:]}",
                    "is_verified": verified,
                    "status": status,
                },
            )
            partners[name] = partner
        return partners

    # ------------------------------------------------------------------
    def _order_items_for(self, restaurant_key, food_name, quantity=1):
        food = Food.objects.get(restaurant__name=restaurant_key, name=food_name)
        return {"food_id": str(food.id), "quantity": quantity}

    def _place(self, customer, restaurant, food_names, *, payment_method="cod", notes=""):
        address = customer.addresses.first()
        items = [self._order_items_for(restaurant.name, name) for name in food_names]
        return order_services.place_order(
            customer, restaurant_id=restaurant.id, address_id=address.id,
            items_payload=items, payment_method=payment_method, notes=notes,
        )

    def _create_orders(self, r, customers, partners):
        if Order.objects.filter(notes__startswith="[demo]").exists():
            self.stdout.write("  = demo orders already exist, skipping order creation")
            return list(Order.objects.filter(notes__startswith="[demo]"))

        deepa, ramesh, sneha = customers[0], customers[1], customers[2]
        aravind = User.objects.filter(phone_number="9876543210").first() or deepa
        rajesh, manoj = partners["Rajesh Kumar"], partners["Manoj Verma"]

        orders = []

        # 1. Freshly placed — restaurant hasn't touched it yet.
        o1 = self._place(deepa, r["spice_garden"], ["Masala Dosa", "Filter Coffee"], notes="[demo] Less spicy please")
        orders.append(o1)

        # 2. Accepted — owner tapped "Accept".
        o2 = self._place(ramesh, r["punjabi_tadka"], ["Butter Chicken", "Butter Naan"], notes="[demo]")
        order_services.update_order_status(o2, OrderStatus.ACCEPTED)
        orders.append(o2)

        # 3. Preparing.
        o3 = self._place(sneha, r["punjabi_tadka"], ["Paneer Tikka", "Dal Makhani"], notes="[demo]")
        order_services.update_order_status(o3, OrderStatus.ACCEPTED)
        order_services.update_order_status(o3, OrderStatus.PREPARING)
        orders.append(o3)

        # 4. Ready for pickup — sitting on the delivery app's job board.
        o4 = self._place(aravind, r["pizza_point"], ["Margherita", "Garlic Bread"], notes="[demo]")
        order_services.update_order_status(o4, OrderStatus.ACCEPTED)
        order_services.update_order_status(o4, OrderStatus.PREPARING)
        order_services.update_order_status(o4, OrderStatus.READY_FOR_PICKUP)
        orders.append(o4)

        # 5. Out for delivery — claimed by Manoj, who stays "on_delivery".
        o5 = self._place(deepa, r["spice_garden"], ["Chicken Chettinad", "Sambar Rice"], notes="[demo]")
        order_services.update_order_status(o5, OrderStatus.ACCEPTED)
        order_services.update_order_status(o5, OrderStatus.PREPARING)
        order_services.update_order_status(o5, OrderStatus.READY_FOR_PICKUP)
        delivery_services.accept_order(o5, manoj)
        orders.append(o5)

        # 6 & 7. Delivered — walked all the way through by Rajesh, who ends back online.
        o6 = self._place(ramesh, r["spice_garden"], ["Idli (2 pcs)", "Pongal"], notes="[demo]")
        order_services.update_order_status(o6, OrderStatus.ACCEPTED)
        order_services.update_order_status(o6, OrderStatus.PREPARING)
        order_services.update_order_status(o6, OrderStatus.READY_FOR_PICKUP)
        delivery_services.accept_order(o6, rajesh)
        delivery_services.mark_delivered(o6, rajesh)
        orders.append(o6)

        o7 = self._place(aravind, r["punjabi_tadka"], ["Paneer Butter Masala", "Tandoori Roti"], payment_method="online", notes="[demo]")
        order_services.update_order_status(o7, OrderStatus.ACCEPTED)
        order_services.update_order_status(o7, OrderStatus.PREPARING)
        order_services.update_order_status(o7, OrderStatus.READY_FOR_PICKUP)
        delivery_services.accept_order(o7, rajesh)
        delivery_services.mark_delivered(o7, rajesh)
        orders.append(o7)

        # 8. Cancelled by the customer while still placed.
        o8 = self._place(sneha, r["pizza_point"], ["Chicken Pepperoni"], notes="[demo]")
        order_services.cancel_order(o8, sneha, reason="Changed my mind")
        orders.append(o8)

        for o in orders:
            self.stdout.write(f"  + order {o.order_number} -> {o.status}")
        return orders

    # ------------------------------------------------------------------
    def _create_reviews(self, orders):
        delivered = [o for o in orders if o.status == OrderStatus.DELIVERED]
        comments = [
            (5, "Excellent food, arrived hot and on time!"),
            (4, "Really good, will order again."),
        ]
        for order, (rating, comment) in zip(delivered, comments):
            Review.objects.get_or_create(
                user=order.user, order=order,
                defaults={"restaurant": order.restaurant, "rating": rating, "comment": comment},
            )
            first_item = order.items.first()
            if first_item and first_item.food_id:
                FoodReview.objects.get_or_create(
                    user=order.user, food_id=first_item.food_id,
                    defaults={"rating": rating, "comment": comment},
                )

    # ------------------------------------------------------------------
    def _print_credentials(self, owners, customers, partners):
        self.stdout.write(f"\nAll demo accounts use password: {DEMO_PASSWORD}")
        self.stdout.write("\n--- Restaurant owners (restaurant_app, email+password login) ---")
        for o in owners:
            self.stdout.write(f"  {o.email}  ({Restaurant.objects.filter(owner=o).first().name})")
        self.stdout.write("\n--- Delivery partners (delivery_app, email+password login) ---")
        for name, p in partners.items():
            self.stdout.write(f"  {p.user.email}  verified={p.is_verified} status={p.status}")
        self.stdout.write("\n--- Customers (mobile app, phone+OTP login — debug OTP returned by the API) ---")
        for c in customers:
            self.stdout.write(f"  {c.phone_number}  ({c.full_name})")
        self.stdout.write("\n--- Admin (admin_app, email+password login) ---")
        self.stdout.write("  admin@garuda.app")

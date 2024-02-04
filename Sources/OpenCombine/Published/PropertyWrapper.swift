//
//  PropertyWrapper.swift
//  OpenCombine
//
//  Created by liuguoqiang on 2024/2/4.
//

import Foundation

/*
 A property wrapper adds a layer of separation between code that manages how a property is stored and the code that defines a property. For example, if you have properties that provide thread-safety checks or store their underlying data in a database, you have to write that code on every property. When you use a property wrapper, you write the management code once when you define the wrapper, and then reuse that management code by applying it to multiple properties.

 To define a property wrapper, you make a structure, enumeration, or class that defines a wrappedValue property. In the code below, the TwelveOrLess structure ensures that the value it wraps always contains a number less than or equal to 12. If you ask it to store a larger number, it stores 12 instead.

 @propertyWrapper
 struct TwelveOrLess {
     private var number = 0
     var wrappedValue: Int {
         get { return number }
         set { number = min(newValue, 12) }
     }
 }
 The setter ensures that new values are less than or equal to 12, and the getter returns the stored value.

 Note

 The declaration for number in the example above marks the variable as private, which ensures number is used only in the implementation of TwelveOrLess. Code that’s written anywhere else accesses the value using the getter and setter for wrappedValue, and can’t use number directly. For information about private, see Access Control.

 You apply a wrapper to a property by writing the wrapper’s name before the property as an attribute. Here’s a structure that stores a rectangle that uses the TwelveOrLess property wrapper to ensure its dimensions are always 12 or less:

 struct SmallRectangle {
     @TwelveOrLess var height: Int
     @TwelveOrLess var width: Int
 }


 var rectangle = SmallRectangle()
 print(rectangle.height)
 // Prints "0"


 rectangle.height = 10
 print(rectangle.height)
 // Prints "10"


 rectangle.height = 24
 print(rectangle.height)
 // Prints "12"
 The height and width properties get their initial values from the definition of TwelveOrLess, which sets TwelveOrLess.number to zero. The setter in TwelveOrLess treats 10 as a valid value so storing the number 10 in rectangle.height proceeds as written. However, 24 is larger than TwelveOrLess allows, so trying to store 24 end up setting rectangle.height to 12 instead, the largest allowed value.

 When you apply a wrapper to a property, the compiler synthesizes code that provides storage for the wrapper and code that provides access to the property through the wrapper. (The property wrapper is responsible for storing the wrapped value, so there’s no synthesized code for that.) You could write code that uses the behavior of a property wrapper, without taking advantage of the special attribute syntax. For example, here’s a version of SmallRectangle from the previous code listing that wraps its properties in the TwelveOrLess structure explicitly, instead of writing @TwelveOrLess as an attribute:

 struct SmallRectangle {
     private var _height = TwelveOrLess()
     private var _width = TwelveOrLess()
     var height: Int {
         get { return _height.wrappedValue }
         set { _height.wrappedValue = newValue }
     }
     var width: Int {
         get { return _width.wrappedValue }
         set { _width.wrappedValue = newValue }
     }
 }
 The _height and _width properties store an instance of the property wrapper, TwelveOrLess. The getter and setter for height and width wrap access to the wrappedValue property.

 Setting Initial Values for Wrapped Properties
 The code in the examples above sets the initial value for the wrapped property by giving number an initial value in the definition of TwelveOrLess. Code that uses this property wrapper can’t specify a different initial value for a property that’s wrapped by TwelveOrLess — for example, the definition of SmallRectangle can’t give height or width initial values. To support setting an initial value or other customization, the property wrapper needs to add an initializer. Here’s an expanded version of TwelveOrLess called SmallNumber that defines initializers that set the wrapped and maximum value:

 @propertyWrapper
 struct SmallNumber {
     private var maximum: Int
     private var number: Int


     var wrappedValue: Int {
         get { return number }
         set { number = min(newValue, maximum) }
     }


     init() {
         maximum = 12
         number = 0
     }
     init(wrappedValue: Int) {
         maximum = 12
         number = min(wrappedValue, maximum)
     }
     init(wrappedValue: Int, maximum: Int) {
         self.maximum = maximum
         number = min(wrappedValue, maximum)
     }
 }
 The definition of SmallNumber includes three initializers — init(), init(wrappedValue:), and init(wrappedValue:maximum:) — which the examples below use to set the wrapped value and the maximum value. For information about initialization and initializer syntax, see Initialization.

 When you apply a wrapper to a property and you don’t specify an initial value, Swift uses the init() initializer to set up the wrapper. For example:

 struct ZeroRectangle {
     @SmallNumber var height: Int
     @SmallNumber var width: Int
 }


 var zeroRectangle = ZeroRectangle()
 print(zeroRectangle.height, zeroRectangle.width)
 // Prints "0 0"
 The instances of SmallNumber that wrap height and width are created by calling SmallNumber(). The code inside that initializer sets the initial wrapped value and the initial maximum value, using the default values of zero and 12. The property wrapper still provides all of the initial values, like the earlier example that used TwelveOrLess in SmallRectangle. Unlike that example, SmallNumber also supports writing those initial values as part of declaring the property.

 When you specify an initial value for the property, Swift uses the init(wrappedValue:) initializer to set up the wrapper. For example:

 struct UnitRectangle {
     @SmallNumber var height: Int = 1
     @SmallNumber var width: Int = 1
 }


 var unitRectangle = UnitRectangle()
 print(unitRectangle.height, unitRectangle.width)
 // Prints "1 1"
 When you write = 1 on a property with a wrapper, that’s translated into a call to the init(wrappedValue:) initializer. The instances of SmallNumber that wrap height and width are created by calling SmallNumber(wrappedValue: 1). The initializer uses the wrapped value that’s specified here, and it uses the default maximum value of 12.

 When you write arguments in parentheses after the custom attribute, Swift uses the initializer that accepts those arguments to set up the wrapper. For example, if you provide an initial value and a maximum value, Swift uses the init(wrappedValue:maximum:) initializer:

 struct NarrowRectangle {
     @SmallNumber(wrappedValue: 2, maximum: 5) var height: Int
     @SmallNumber(wrappedValue: 3, maximum: 4) var width: Int
 }


 var narrowRectangle = NarrowRectangle()
 print(narrowRectangle.height, narrowRectangle.width)
 // Prints "2 3"


 narrowRectangle.height = 100
 narrowRectangle.width = 100
 print(narrowRectangle.height, narrowRectangle.width)
 // Prints "5 4"
 The instance of SmallNumber that wraps height is created by calling SmallNumber(wrappedValue: 2, maximum: 5), and the instance that wraps width is created by calling SmallNumber(wrappedValue: 3, maximum: 4).

 By including arguments to the property wrapper, you can set up the initial state in the wrapper or pass other options to the wrapper when it’s created. This syntax is the most general way to use a property wrapper. You can provide whatever arguments you need to the attribute, and they’re passed to the initializer.

 When you include property wrapper arguments, you can also specify an initial value using assignment. Swift treats the assignment like a wrappedValue argument and uses the initializer that accepts the arguments you include. For example:

 struct MixedRectangle {
     @SmallNumber var height: Int = 1
     @SmallNumber(maximum: 9) var width: Int = 2
 }


 var mixedRectangle = MixedRectangle()
 print(mixedRectangle.height)
 // Prints "1"


 mixedRectangle.height = 20
 print(mixedRectangle.height)
 // Prints "12"
 The instance of SmallNumber that wraps height is created by calling SmallNumber(wrappedValue: 1), which uses the default maximum value of 12. The instance that wraps width is created by calling SmallNumber(wrappedValue: 2, maximum: 9).

 Projecting a Value From a Property Wrapper
 In addition to the wrapped value, a property wrapper can expose additional functionality by defining a projected value — for example, a property wrapper that manages access to a database can expose a flushDatabaseConnection() method on its projected value. The name of the projected value is the same as the wrapped value, except it begins with a dollar sign ($). Because your code can’t define properties that start with $ the projected value never interferes with properties you define.

 In the SmallNumber example above, if you try to set the property to a number that’s too large, the property wrapper adjusts the number before storing it. The code below adds a projectedValue property to the SmallNumber structure to keep track of whether the property wrapper adjusted the new value for the property before storing that new value.

 @propertyWrapper
 struct SmallNumber {
     private var number: Int
     private(set) var projectedValue: Bool


     var wrappedValue: Int {
         get { return number }
         set {
             if newValue > 12 {
                 number = 12
                 projectedValue = true
             } else {
                 number = newValue
                 projectedValue = false
             }
         }
     }


     init() {
         self.number = 0
         self.projectedValue = false
     }
 }
 struct SomeStructure {
     @SmallNumber var someNumber: Int
 }
 var someStructure = SomeStructure()


 someStructure.someNumber = 4
 print(someStructure.$someNumber)
 // Prints "false"


 someStructure.someNumber = 55
 print(someStructure.$someNumber)
 // Prints "true"
 Writing someStructure.$someNumber accesses the wrapper’s projected value. After storing a small number like four, the value of someStructure.$someNumber is false. However, the projected value is true after trying to store a number that’s too large, like 55.

 A property wrapper can return a value of any type as its projected value. In this example, the property wrapper exposes only one piece of information — whether the number was adjusted — so it exposes that Boolean value as its projected value. A wrapper that needs to expose more information can return an instance of some other type, or it can return self to expose the instance of the wrapper as its projected value.

 When you access a projected value from code that’s part of the type, like a property getter or an instance method, you can omit self. before the property name, just like accessing other properties. The code in the following example refers to the projected value of the wrapper around height and width as $height and $width:

 enum Size {
     case small, large
 }


 struct SizedRectangle {
     @SmallNumber var height: Int
     @SmallNumber var width: Int


     mutating func resize(to size: Size) -> Bool {
         switch size {
         case .small:
             height = 10
             width = 20
         case .large:
             height = 100
             width = 100
         }
         return $height || $width
     }
 }
 Because property wrapper syntax is just syntactic sugar for a property with a getter and a setter, accessing height and width behaves the same as accessing any other property. For example, the code in resize(to:) accesses height and width using their property wrapper. If you call resize(to: .large), the switch case for .large sets the rectangle’s height and width to 100. The wrapper prevents the value of those properties from being larger than 12, and it sets the projected value to true, to record the fact that it adjusted their values. At the end of resize(to:), the return statement checks $height and $width to determine whether the property wrapper adjusted either height or width.
 */

/*
 属性包装器在管理属性存储的代码和定义属性的代码之间添加了一层分离。例如，如果您的属性需要进行线程安全检查或将其基础数据存储在数据库中，您必须在每个属性上编写这些代码。当您使用属性包装器时，您只需在定义包装器时编写一次管理代码，然后通过将其应用于多个属性来重用该管理代码。

 要定义属性包装器，您需要创建一个结构体、枚举或类，该结构体、枚举或类定义了`wrappedValue`属性。在下面的代码中，`TwelveOrLess`结构确保它包装的值始终包含小于或等于12的数字。如果要求存储较大的数字，它将存储为12。

 ```swift
 @propertyWrapper
 struct TwelveOrLess {
     private var number = 0
     var wrappedValue: Int {
         get { return number }
         set { number = min(newValue, 12) }
     }
 }
 ```

 Setter确保新值小于或等于12，而Getter返回存储的值。

 **注意**

 上面示例中`number`的声明将变量标记为私有，这确保`number`只在`TwelveOrLess`的实现中使用。在任何其他地方编写的代码都使用`wrappedValue`的getter和setter访问该值，不能直接使用`number`。有关`private`的信息，请参阅[访问控制](https://docs.swift.org/swift-book/LanguageGuide/AccessControl.html)。

 通过将包装器的名称写在属性之前作为属性，您将包装器应用于属性。下面的结构存储使用`TwelveOrLess`属性包装器确保其尺寸始终为12或更小的矩形：

 ```swift
 struct SmallRectangle {
     @TwelveOrLess var height: Int
     @TwelveOrLess var width: Int
 }

 var rectangle = SmallRectangle()
 print(rectangle.height)
 // 打印 "0"

 rectangle.height = 10
 print(rectangle.height)
 // 打印 "10"

 rectangle.height = 24
 print(rectangle.height)
 // 打印 "12"
 ```

 `height`和`width`属性从`TwelveOrLess`的定义中获取初始值，该定义将`TwelveOrLess.number`设置为零。`TwelveOrLess`的setter将10视为有效值，因此将数字10存储在`rectangle.height`中。然而，24大于`TwelveOrLess`允许的值，因此试图将24存储在`rectangle.height`中最终将其设置为12，即允许的最大值。

 当您将包装器应用于属性时，编译器将合成代码，为包装器提供存储并通过包装器提供对属性的访问的代码。 （包装器负责存储封装值，因此没有为此合成代码。）
 您可以编写使用属性包装器行为的代码，而不使用特殊的属性语法。例如，下面的代码显示了一个版本的`SmallRectangle`，该版本在`TwelveOrLess`的定义中显式包装其属性，而不是将`@TwelveOrLess`写为属性：

 ```swift
 struct SmallRectangle {
     private var _height = TwelveOrLess()
     private var _width = TwelveOrLess()
     var height: Int {
         get { return _height.wrappedValue }
         set { _height.wrappedValue = newValue }
     }
     var width: Int {
         get { return _width.wrappedValue }
         set { _width.wrappedValue = newValue }
     }
 }
 ```

 `_height`和`_width`属性存储`TwelveOrLess`结构的一个实例。`height`和`width`的getter和setter将访问封装值的访问包装在`wrappedValue`属性中。

 ### 为包装的属性设置初始值

 上面的示例代码在定义`TwelveOrLess`时通过为`number`赋初值来设置包装属性的初始值。使用此属性包装器的代码不能为由`TwelveOrLess`包装的属性指定不同的初始值 - 例如，`SmallRectangle`的定义不能给`height`或`width`指定初始值。为了支持设置初始值或其他自定义，属性包装器需要添加一个初始化程序。

 下面是一个名为`SmallNumber`的扩展版本，它定义了一个设置封装和最大值的初始化程序，称为`wrappedValue`：

 ```swift
 @propertyWrapper
 struct SmallNumber {
     private var maximum: Int
     private var number: Int

     var wrappedValue: Int {
         get { return number }
         set { number = min(newValue, maximum) }
     }

     init() {
         maximum = 12
         number = 0
     }
     init(wrappedValue: Int) {
         maximum = 12
         number = min(wrappedValue, maximum)
     }
     init(wrappedValue: Int, maximum: Int) {
         self.maximum = maximum
         number = min(wrappedValue, maximum)
     }
 }
 ```

 `SmallNumber`的定义包括三个初始化程序 - `init()`，`init(wrappedValue:)`和`init(wrappedValue:maximum:)`，以下示例使用这些初始化程序来设置包装值和最大值。

 在将包装器应用于属性时，如果未指定初始值，Swift将使用`init()`初始化程序设置包装器。例如：

 ```swift
 struct ZeroRectangle {
     @SmallNumber var height: Int
     @SmallNumber var width: Int
 }

 var zeroRectangle = ZeroRectangle()
 print(zeroRectangle.height, zeroRectangle.width)
 // 打印 "0 0"
 ```

 封装`height`和`width`的`SmallNumber`实例是通过调用`SmallNumber()`创建的。该初始化程序中的代码设置了初始封装值和初始最大值，使用零和12的默认值。
 属性包装器仍然提供所有初始值，就像之前使用`TwelveOrLess`在`SmallRectangle`中的示例一样。与该示例不同，`SmallNumber`还支持将这些初始值写为声明属性的一部分。

 当为属性指定初始值时，Swift

 使用`init(wrappedValue:)`初始化程序设置包装器。例如：

 ```swift
 struct UnitRectangle {
     @SmallNumber var height: Int = 1
     @SmallNumber var width: Int = 1
 }

 var unitRectangle = UnitRectangle()
 print(unitRectangle.height, unitRectangle.width)
 // 打印 "1 1"
 ```

 当在属性上写`=` 1时，这被转换为对`init(wrappedValue:)`初始化程序的调用。封装`height`和`width`的`SmallNumber`实例是通过调用`SmallNumber(wrappedValue: 1)`创建的。该初始化程序使用在此处指定的封装值，并使用默认的最大值12。

 当您在自定义属性后的括号中提供参数时，Swift将使用接受这些参数的初始化程序设置包装器。例如，如果提供初始值和最大值，Swift将使用`init(wrappedValue:maximum:)`初始化程序：

 ```swift
 struct NarrowRectangle {
     @SmallNumber(wrappedValue: 2, maximum: 5) var height: Int
     @SmallNumber(wrappedValue: 3, maximum: 4) var width: Int
 }

 var narrowRectangle = NarrowRectangle()
 print(narrowRectangle.height, narrowRectangle.width)
 // 打印 "2 3"

 narrowRectangle.height = 100
 narrowRectangle.width = 100
 print(narrowRectangle.height, narrowRectangle.width)
 // 打印 "5 4"
 ```

 封装`height`的`SmallNumber`实例通过调用`SmallNumber(wrappedValue: 2, maximum: 5)`创建，而封装`width`的实例通过调用`SmallNumber(wrappedValue: 3, maximum: 4)`创建。

 通过包含属性包装器参数，您可以在包装器中设置初始状态或在创建时向包装器传递其他选项。这种语法是使用属性包装器的最一般方式。您可以向属性包装器提供您需要的任何参数，并将它们传递给初始化程序。

 当您包含属性包装器参数时，还可以使用赋值指定初始值。Swift将此赋值视为对包含的参数进行初始化程序调用，并使用您包含的参数来设置包装器。例如：

 ```swift
 struct MixedRectangle {
     @SmallNumber var height: Int = 1
     @SmallNumber(maximum: 9) var width: Int = 2
 }

 var mixedRectangle = MixedRectangle()
 print(mixedRectangle.height)
 // 打印 "1"

 mixedRectangle.height = 20
 print(mixedRectangle.height)
 // 打印 "12"
 ```

 封装`height`的`SmallNumber`实例通过调用`SmallNumber(wrappedValue: 1)`创建，使用默认的最大值12。封装`width`的实例通过调用`SmallNumber(wrappedValue: 2, maximum: 9)`创建。

 ### 从属性包装器中投影值

 除了包装值之外，属性包装器还可以通过定义投影值来公开附加功能 - 例如，管理对数据库的访问的属性包装器可以在其投影值上公开`flushDatabaseConnection()`方法。投影值的名称与包装值相同，只是以美元符号（$）开头。由于您的代码不能定义以$开头的属性，投影值永远不会干扰您定义的属性。

 在上面的`SmallNumber`示例中，如果您尝试将属性设置为一个太大的数字，属性包装器将在存储新值之前调整该数字。下面的代码向`SmallNumber`结构添加了一个`projectedValue`属性，以跟踪属性包装器在存储新值之前是否调整了该属性的值。

 ```swift
 @propertyWrapper
 struct SmallNumber {
     private var number: Int
     private(set) var projectedValue: Bool

     var wrappedValue: Int {
         get { return number }
         set {
             if newValue > 12 {
                 number = 12
                 projectedValue = true
             } else {
                 number = newValue
                 projectedValue = false
             }
         }
     }

     init() {
         self.number = 0
         self.projectedValue = false
     }
 }
 struct SomeStructure {
     @SmallNumber var someNumber: Int
 }
 var someStructure = SomeStructure()

 someStructure.someNumber = 4
 print(someStructure.$someNumber)
 // 打印 "false"

 someStructure.someNumber = 55
 print(someStructure.$someNumber)
 // 打印 "true"
 ```

 编写`someStructure.$someNumber`会访问包装器的投影值。在存储小数字（例如4）之后，`someStructure.$someNumber`的值为false。然而，在尝试存储一个太大的数字，如55之后，投影值为true。

 属性包装器可以将其投影值的类型设置为任何类型的值。在此示例中，属性包装器仅公开一个信息 - 数字是否调整 - 因此将该布尔值作为其投影值公开。需要公开更多信息的包装器可以将其投影值设置为某个其他类型的实例，或者可以返回self以将包装器的实例公开为其投影值。

 当您从类型的一部分（例如属性getter或实例方法）访问投影值时，您可以省略属性名称前的`self.`，就像访问其他属性一样。下面的示例中的代码将包裹高度和宽度的包装器的投影值称为`$height`和`$width`：

 ```swift
 enum Size {
     case small, large
 }

 struct SizedRectangle {
     @SmallNumber var height: Int
     @SmallNumber var width: Int

     mutating func resize(to size: Size) -> Bool {
         switch size {
         case .small:
             height = 10
             width = 20
         case .large:
             height = 100
             width = 100
         }
         return $height || $width
     }
 }
 ```

 由于属性包装器语法只是属性getter和setter的语法糖，访问`height`和`width`的行为与访问其他属性相同。例如，`resize(to:)`中的代码使用属性包装器的getter和setter访问`height`和`width`。如果调用`resize(to: .large)`，则`.large`的开关情况将矩形的高度和宽度设置为100。包装器阻止这些属性的值大于12，它将投影值设置为true，以记录调整其值的事实。在`resize(to:)`的末尾，返回语句检查$height和$width，以确定属性包装器是否调整了height或width中的任何一个值。
 */
